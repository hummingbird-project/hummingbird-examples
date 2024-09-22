//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
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
import NIO

struct UserController {
    typealias Context = TodosAuthRequestContext
    let fluent: Fluent
    let sessionAuthenticator: SessionAuthenticator<Context, UserRepository>

    /// Add routes for user controller
    func addRoutes(to group: RouterGroup<Context>) {
        group.post(use: self.create)
        group.group("login")
            .add(middleware: BasicAuthenticator(users: self.sessionAuthenticator.users))
            .post(use: self.login)
        group.add(middleware: self.sessionAuthenticator)
            .get(use: self.current)
            .post("logout", use: self.logout)
    }

    /// Create new user
    /// Used in tests, as user creation is done by ``WebController.signupDetails``
    @Sendable func create(_ request: Request, context: Context) async throws -> EditedResponse<UserResponse> {
        let createUser = try await request.decode(as: CreateUserRequest.self, context: context)

        let user = try await User.create(
            name: createUser.name,
            email: createUser.email,
            password: createUser.password,
            db: self.fluent.db()
        )

        return .init(status: .created, response: UserResponse(from: user))
    }

    /// Login user and create session
    /// Used in tests, as user creation is done by ``WebController.loginDetails``
    @Sendable func login(_ request: Request, context: Context) async throws -> HTTPResponse.Status {
        // get authenticated user and return
        let user = try context.auth.require(User.self)
        try context.sessions.setSession(user.requireID())
        return .ok
    }

    /// Login user and create session
    @Sendable func logout(_ request: Request, context: Context) async throws -> HTTPResponse.Status {
        context.sessions.clearSession()
        return .ok
    }

    /// Get current logged in user
    @Sendable func current(_ request: Request, context: Context) throws -> UserResponse {
        // get authenticated user and return
        let user = try context.auth.require(User.self)
        return UserResponse(from: user)
    }
}
