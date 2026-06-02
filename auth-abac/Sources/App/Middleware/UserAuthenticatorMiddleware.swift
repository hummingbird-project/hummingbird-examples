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
import Hummingbird
import HummingbirdAuth
import HummingbirdBcrypt
import HummingbirdFluent
import NIOPosix

/// Stage 1 of identity assembly: verify Basic auth credentials and write the
/// resolved ``User`` into `context.authenticatedUser`.
///
/// `context.identity` is left `nil` after this middleware — it is promoted to a
/// full ``DocumentRequest`` by either ``DocumentResolverMiddleware`` (document
/// routes) or ``UserIdentityMiddleware`` (non-document routes).
///
/// Throws `401 Unauthorized` if:
/// - No `Authorization: Basic …` header is present.
/// - The username does not match any user in the database.
/// - The supplied password does not match the stored hash.
struct UserAuthenticatorMiddleware: RouterMiddleware {
    typealias Context = AppRequestContext

    let fluent: Fluent

    func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        guard let basic = request.headers.basic else {
            throw HTTPError(.unauthorized)
        }
        guard
            let user = try await User.query(on: fluent.db())
                .filter(\.$name == basic.username)
                .first()
        else {
            throw HTTPError(.unauthorized)
        }
        guard
            let hash = user.passwordHash,
            try await NIOThreadPool.singleton.runIfActive({ Bcrypt.verify(basic.password, hash: hash) })
        else {
            throw HTTPError(.unauthorized)
        }
        var context = context
        context.authenticatedUser = user
        return try await next(request, context)
    }
}
