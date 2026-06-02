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

struct UserController: Sendable {
    typealias Context = AppRequestContext
    let fluent: Fluent

    func addRoutes(to group: RouterGroup<Context>) {
        group.put(use: self.create)
    }

    /// Create a new user with ABAC subject attributes (department, clearance level,
    /// roles, permissions). Returns `201 Created` with a ``UserResponse``.
    func create(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<UserResponse> {
        let body = try await request.decode(as: CreateUserRequest.self, context: context)
        let db = self.fluent.db()

        let existing = try await User.query(on: db).filter(\.$name == body.name).first()
        guard existing == nil else { throw HTTPError(.conflict) }

        let passwordHash = try await NIOThreadPool.singleton.runIfActive {
            Bcrypt.hash(body.password, cost: 12)
        }

        let user = User(
            name: body.name,
            passwordHash: passwordHash,
            department: body.department,
            clearanceLevel: body.clearanceLevel,
            rolesList: body.roles.joined(separator: ","),
            permissionsList: body.permissions.joined(separator: ",")
        )
        try await user.save(on: db)
        return .init(status: .created, response: UserResponse(from: user))
    }
}
