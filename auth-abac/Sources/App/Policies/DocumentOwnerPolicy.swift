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

import Hummingbird
import HummingbirdAuth

/// Passes only when the authenticated user is the owner of the requested document
/// (`document.ownerID == user.id`).
///
/// Because ``DocumentResolverMiddleware`` fetches the document exactly once before
/// any policy runs, this is a pure in-memory identity comparison — no database
/// calls, no async work, no injected dependencies.
///
/// Compose with ``RolePolicy`` so admins can always update:
///
/// ```swift
/// .authorized {
///     anyOf(RolePolicy(.admin), DocumentOwnerPolicy())
/// }
/// ```
struct DocumentOwnerPolicy: AuthorizationPolicy {
    typealias Identity = DocumentRequest

    func isAuthorized(identity: DocumentRequest, request: Request) async throws -> Bool {
        guard let document = identity.document else { return false }
        return document.ownerID == identity.user.id
    }
}
