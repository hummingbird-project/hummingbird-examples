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
import HummingbirdFluent

/// Stage 2 of identity assembly for document routes: fetch the document from the
/// `:id` path parameter **exactly once** and bundle it with the authenticated user
/// into a ``DocumentRequest`` identity.
///
/// Must run after ``UserAuthenticatorMiddleware`` (which sets `context.authenticatedUser`).
/// After this middleware, `context.identity` is fully populated and every downstream
/// policy or handler can access both `identity.user` and `identity.document` without
/// any further database calls.
///
/// Throws:
/// - `401 Unauthorized` if `context.authenticatedUser` is not set (middleware ordering error).
/// - `404 Not Found` if no document matches the `:id` path parameter.
struct DocumentResolverMiddleware: RouterMiddleware {
    typealias Context = AppRequestContext

    let fluent: Fluent

    func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        guard let user = context.authenticatedUser else {
            throw HTTPError(.unauthorized)
        }
        let id = try context.parameters.require("id", as: UUID.self)
        guard let document = try await Document.find(id, on: fluent.db()) else {
            throw HTTPError(.notFound)
        }
        var context = context
        context.identity = DocumentRequest(user: user, document: document)
        return try await next(request, context)
    }
}
