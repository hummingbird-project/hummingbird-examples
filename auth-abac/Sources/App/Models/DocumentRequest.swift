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

import HummingbirdAuth

/// The composite identity that flows through document-scoped routes.
///
/// Assembled once by ``DocumentResolverMiddleware`` after the user has been
/// authenticated. All downstream policies and handlers operate on the
/// already-resolved values — no further database calls required.
///
/// Routes that authenticate but do not operate on a specific document (e.g.
/// `POST /documents`) receive a ``DocumentRequest`` with `document: nil`,
/// assembled by ``UserIdentityMiddleware``.
struct DocumentRequest: Sendable {
    /// The authenticated user (subject attributes).
    let user: User
    /// The document being acted on (resource attributes), or `nil` for routes
    /// that do not target a specific document.
    let document: Document?
}

// MARK: - RoleProviding / PermissionProviding delegation

/// Delegate role and permission lookups to the underlying user so that
/// ``RolePolicy`` and ``PermissionPolicy`` work transparently on ``DocumentRequest``.
extension DocumentRequest: RoleProviding {
    var roles: Set<Role> { user.roles }
}

extension DocumentRequest: PermissionProviding {
    var permissions: Set<Permission> { user.permissions }
}
