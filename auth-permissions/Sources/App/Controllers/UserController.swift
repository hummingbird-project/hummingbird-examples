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
import HummingbirdBcrypt
import HummingbirdFluent
import NIOPosix

struct UserController {
    typealias Context = AppRequestContext
    let fluent: Fluent

    /// Register routes on `PUT /user`
    func addRoutes(to group: RouterGroup<Context>) {
        group.put(use: self.create)
    }

    /// Create a new user account.
    ///
    /// Accepts `CreateUserRequest` (name, password, roles, permissions) and
    /// returns `201 Created` with a `UserResponse`.
    func create(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<UserResponse> {
        let createUser = try await request.decode(as: CreateUserRequest.self, context: context)
        let db = self.fluent.db()

        // Reject duplicate usernames
        let existing = try await User.query(on: db)
            .filter(\.$name == createUser.name)
            .first()
        guard existing == nil else { throw HTTPError(.conflict) }

        // Hash the password off the main thread pool
        let passwordHash: String?
        if let password = createUser.password {
            passwordHash = try await NIOThreadPool.singleton.runIfActive {
                Bcrypt.hash(password, cost: 12)
            }
        } else {
            passwordHash = nil
        }

        let user = User(
            name: createUser.name,
            passwordHash: passwordHash,
            rolesList: createUser.roles.joined(separator: ","),
            permissionsList: createUser.permissions.joined(separator: ",")
        )
        try await user.save(on: db)
        return .init(status: .created, response: UserResponse(from: user))
    }
}
