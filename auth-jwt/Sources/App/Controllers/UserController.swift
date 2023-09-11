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
import JWTKit
import NIO

struct UserController {
    let jwtSigners: JWTSigners

    /// Add routes for user controller
    func addRoutes(to group: HBRouterGroup) {
        group.put(use: self.create)
        group.group("login").add(middleware: BasicAuthenticator())
            .post(use: self.login)
    }

    /// Create new user
    func create(_ request: HBRequest) async throws -> UserResponse {
        guard let createUser = try? request.decode(as: CreateUserRequest.self) else { throw HBHTTPError(.badRequest) }
        // check if user exists and if they don't then add new user
        let existingUser = try await User.query(on: request.db)
            .filter(\.$name == createUser.name)
            .first()
        // if user already exist throw conflict
        guard existingUser == nil else { throw HBHTTPError(.conflict) }

        let user = User(from: createUser)
        try await user.save(on: request.db)

        return UserResponse(from: user)
    }

    /// Login user and return JWT
    func login(_ request: HBRequest) async throws -> [String: String] {
        // get authenticated user and return
        let user = try request.authRequire(User.self)
        let payload = JWTPayloadData(
            subject: .init(value: user.name),
            expiration: .init(value: Date(timeIntervalSinceNow: 12 * 60 * 60))
        )
        return try [
            "token": self.jwtSigners.sign(payload, kid: "_hb_local_"),
        ]
    }
}
