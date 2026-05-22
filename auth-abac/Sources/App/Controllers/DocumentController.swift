//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import FluentKit
import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent

/// Routes under `/documents` with composite-identity ABAC authorization.
///
/// The middleware pipeline has two stages before any policy runs:
///
/// 1. `UserAuthenticatorMiddleware` — verifies credentials, sets `context.authenticatedUser`.
/// 2. Either `DocumentResolverMiddleware` (`:id` routes) or `UserIdentityMiddleware`
///    (collection routes) — fetches the document **once** and assembles the
///    `DocumentRequest` identity.
///
/// By the time a policy or handler executes, `context.identity` contains both the
/// user and the document (if applicable). Policies perform zero additional DB calls.
///
/// | Method | Path            | Stage-2 middleware        | Policy                                             |
/// |--------|-----------------|---------------------------|----------------------------------------------------|
/// | GET    | /documents      | — (public)                | none                                               |
/// | POST   | /documents      | `UserIdentityMiddleware`  | `PermissionPolicy(.documentsCreate)`                           |
/// | GET    | /documents/:id  | `DocumentResolverMiddleware` | `anyOf(admin, allOf(same-dept, clearance))`               |
/// | PUT    | /documents/:id  | `DocumentResolverMiddleware` | `anyOf(admin, owner)`                                     |
/// | DELETE | /documents/:id  | `DocumentResolverMiddleware` | `allOf(admin, business-hours)`                            |
struct DocumentController: Sendable {
    typealias Context = AppRequestContext
    let fluent: Fluent
    let allowedDeletionHours: Range<Int>

    func addRoutes(to group: RouterGroup<Context>) {
        // Public: list all documents (no auth)
        group.get(use: self.list)

        // Stage 1: verify credentials for all protected routes
        let authed = group.group()
            .add(middleware: UserAuthenticatorMiddleware(fluent: self.fluent))

        // POST /documents — user needs documents:create permission; no existing document
        authed.group()
            .add(middleware: UserIdentityMiddleware())
            .add(middleware: AuthorizationPolicyMiddleware(PermissionPolicy(.documentsCreate)))
            .post(use: self.create)

        // GET /documents/:id — same dept AND sufficient clearance, OR admin
        authed.group(":id")
            .add(middleware: DocumentResolverMiddleware(fluent: self.fluent))
            .add(
                middleware: AuthorizationPolicyMiddleware(
                    anyOf {
                        RolePolicy(.admin)
                        allOf {
                            SameDepartmentPolicy()
                            SufficientClearancePolicy()
                        }
                    }
                )
            )
            .get(use: self.get)

        // PUT /documents/:id — owner OR admin
        authed.group(":id")
            .add(middleware: DocumentResolverMiddleware(fluent: self.fluent))
            .add(
                middleware: AuthorizationPolicyMiddleware(
                    anyOf {
                        RolePolicy(.admin)
                        DocumentOwnerPolicy()
                    }
                )
            )
            .put(use: self.update)

        // DELETE /documents/:id — admin AND within allowed hours
        authed.group(":id")
            .add(middleware: DocumentResolverMiddleware(fluent: self.fluent))
            .add(
                middleware: AuthorizationPolicyMiddleware(
                    allOf {
                        RolePolicy(.admin)
                        BusinessHoursPolicy(allowedHours: self.allowedDeletionHours)
                    }
                )
            )
            .delete(use: self.delete)
    }

    // MARK: - Handlers

    func list(_ request: Request, context: Context) async throws -> [DocumentResponse] {
        try await Document.query(on: self.fluent.db()).all().map { DocumentResponse(from: $0) }
    }

    func create(_ request: Request, context: Context) async throws -> EditedResponse<DocumentResponse> {
        guard let identity = context.identity else { throw HTTPError(.unauthorized) }
        guard let ownerID = identity.user.id else { throw HTTPError(.internalServerError) }

        let body = try await request.decode(as: CreateDocumentRequest.self, context: context)
        let document = Document(
            title: body.title,
            content: body.content,
            department: body.department,
            classification: body.classification,
            ownerID: ownerID
        )
        try await document.save(on: self.fluent.db())
        return .init(status: .created, response: DocumentResponse(from: document))
    }

    /// Document already resolved by `DocumentResolverMiddleware` — no DB call needed.
    func get(_ request: Request, context: Context) async throws -> DocumentResponse {
        guard let document = context.identity?.document else { throw HTTPError(.notFound) }
        return DocumentResponse(from: document)
    }

    /// Document already resolved; update fields and persist.
    func update(_ request: Request, context: Context) async throws -> DocumentResponse {
        guard let document = context.identity?.document else { throw HTTPError(.notFound) }
        let body = try await request.decode(as: UpdateDocumentRequest.self, context: context)
        if let title = body.title { document.title = title }
        if let content = body.content { document.content = content }
        try await document.save(on: self.fluent.db())
        return DocumentResponse(from: document)
    }

    /// Document already resolved; delete and return 200.
    func delete(_ request: Request, context: Context) async throws -> HTTPResponse.Status {
        guard let document = context.identity?.document else { throw HTTPError(.notFound) }
        try await document.delete(on: self.fluent.db())
        return .ok
    }
}
