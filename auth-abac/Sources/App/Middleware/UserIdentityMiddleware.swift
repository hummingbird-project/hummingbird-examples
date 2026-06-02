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

/// Stage 2 of identity assembly for non-document routes: promote the authenticated
/// ``User`` (set by ``UserAuthenticatorMiddleware``) into a ``DocumentRequest``
/// identity with `document: nil`.
///
/// Use this on routes that require authentication but do not operate on a specific
/// existing document — for example `POST /documents` (create) or `GET /documents`
/// (list). ``RolePolicy`` and ``PermissionPolicy`` work normally because
/// ``DocumentRequest`` delegates both to the underlying user.
///
/// Throws `401 Unauthorized` if `context.authenticatedUser` is not set.
struct UserIdentityMiddleware: RouterMiddleware {
    typealias Context = AppRequestContext

    func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        guard let user = context.authenticatedUser else {
            throw HTTPError(.unauthorized)
        }
        var context = context
        context.identity = DocumentRequest(user: user, document: nil)
        return try await next(request, context)
    }
}
