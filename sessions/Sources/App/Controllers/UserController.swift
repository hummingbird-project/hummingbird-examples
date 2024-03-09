//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
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
import HummingbirdFluent
import NIO

struct UserController {
    let fluent: HBFluent
    let sessionStorage: HBSessionStorage

    init(fluent: HBFluent, sessionStorage: HBSessionStorage) {
        self.fluent = fluent
        self.sessionStorage = sessionStorage
    }

    /// Add routes for user controller
    func addRoutes(to group: HBRouterGroup<SessionsContext>) {
        group
            .put(use: self.create)
        group.group("login")
            .add(middleware: BasicAuthenticator(fluent: self.fluent))
            .post(use: self.login)
        group
            .add(middleware: SessionAuthenticator(sessionStorage: self.sessionStorage, fluent: self.fluent))
            .get(use: self.current)
    }

    /// Create new user
    @Sendable func create(_ request: HBRequest, context: SessionsContext) async throws -> UserResponse {
        let createUser = try await request.decode(as: CreateUserRequest.self, context: context)
        // check if user exists and if they don't then add new user
        let existingUser = try await User.query(on: self.fluent.db())
            .filter(\.$name == createUser.name)
            .first()
        // if user already exist throw conflict
        guard existingUser == nil else { throw HBHTTPError(.conflict) }

        let user = try await User(from: createUser)
        try await user.save(on: self.fluent.db())

        return try UserResponse(from: user)
    }

    /// Login user and create session
    @Sendable func login(_ request: HBRequest, context: SessionsContext) async throws -> HBResponse {
        // get authenticated user and return
        let user = try context.auth.require(LoggedInUser.self)
        // create session lasting 1 hour
        let cookie = try await self.sessionStorage.save(session: user.id, expiresIn: .seconds(60))
        return .init(status: .ok, headers: [.setCookie: cookie.description])
    }

    /// Get current logged in user
    @Sendable func current(_ request: HBRequest, context: SessionsContext) throws -> UserResponse {
        // get authenticated user and return
        let user = try context.auth.require(LoggedInUser.self)
        return UserResponse(id: user.id, name: user.name)
    }
}
