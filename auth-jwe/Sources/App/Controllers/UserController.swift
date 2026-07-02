//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2026 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdBasicAuth
import JWSETKit

struct UserController {
    typealias Context = AppRequestContext
    let keys: TokenKeys
    let users: UserStore
    let issuer: String
    let audience: String

    func addRoutes(to group: RouterGroup<Context>) {
        group.group("login")
            .add(middleware: BasicAuthenticator { username, _ in
                self.users.user(named: username)
            })
            .post(use: self.login)
    }

    /// Login user and return an encrypted, signed token.
    @Sendable func login(_ request: Request, context: Context) async throws -> [String: String] {
        guard let user = context.identity else { throw Hummingbird.HTTPError(.unauthorized) }
        let token = try user.issueNestedToken(keys: self.keys, issuer: self.issuer, audience: self.audience)
        return ["token": token]
    }
}
