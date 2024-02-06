//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
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
import JWTKit
import NIO

struct UserController<Context: HBAuthRequestContextProtocol> {
    let jwtSigners: JWTSigners
    let kid: JWKIdentifier
    let fluent: HBFluent

    /// Add routes for user controller
    func addRoutes(to group: HBRouterGroup<Context>) {
        group.put(use: self.create)
        group.group("login").add(middleware: BasicAuthenticator(fluent: fluent))
            .post(use: self.login)
    }

    /// Create new user
    @Sendable func create(_ request: HBRequest, context: Context) async throws -> HBEditedResponse<UserResponse> {
        let createUser = try await request.decode(as: CreateUserRequest.self, context: context)
        let db = fluent.db()
        // check if user exists and if they don't then add new user
        let existingUser = try await User.query(on: db)
            .filter(\.$name == createUser.name)
            .first()
        // if user already exist throw conflict
        guard existingUser == nil else { throw HBHTTPError(.conflict) }

        let user = User(from: createUser)
        try await user.save(on: db)

        return .init(status: .created, response: UserResponse(from: user))
    }

    /// Login user and return JWT
    @Sendable func login(_ request: HBRequest, context: Context) async throws -> [String: String] {
        // get authenticated user and return
        let user = try context.auth.require(AuthenticatedUser.self)
        let payload = JWTPayloadData(
            subject: .init(value: user.name),
            expiration: .init(value: Date(timeIntervalSinceNow: 12 * 60 * 60))
        )
        return try [
            "token": self.jwtSigners.sign(payload, kid: self.kid),
        ]
    }
}
