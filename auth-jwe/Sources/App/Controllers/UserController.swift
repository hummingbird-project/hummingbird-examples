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

import FluentKit
import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdBasicAuth
import HummingbirdFluent
import JWSETKit

struct UserController {
    typealias Context = AppRequestContext
    let keys: TokenKeys
    let fluent: Fluent
    let issuer: String
    let audience: String

    func addRoutes(to group: RouterGroup<Context>) {
        group.put(use: self.create)
        group.group("login")
            .add(middleware: BasicAuthenticator { username, _ in
                try await User.query(on: self.fluent.db()).filter(\.$name == username).first()
            })
            .post(use: self.login)
    }

    /// Create a new user.
    @Sendable func create(_ request: Request, context: Context) async throws -> EditedResponse<UserResponse> {
        let createUser = try await request.decode(as: CreateUserRequest.self, context: context)
        let db = self.fluent.db()
        let existing = try await User.query(on: db).filter(\.$name == createUser.name).first()
        guard existing == nil else { throw HTTPError(.conflict) }
        let user = try await User(from: createUser)
        try await user.save(on: db)
        return .init(status: .created, response: UserResponse(from: user))
    }

    /// Login user and return an encrypted, signed token.
    @Sendable func login(_ request: Request, context: Context) async throws -> [String: String] {
        let user = try context.requireIdentity()
        let token = try user.issueNestedToken(keys: self.keys, issuer: self.issuer, audience: self.audience)
        return ["token": token]
    }
}
