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
import NIO

struct UserController {
    /// Add routes for user controller
    func addRoutes(to group: HBRouterGroup) {
        group.put(use: self.create)
        group.group("login").add(middleware: BasicAuthenticator())
            .post(use: self.login)
        group.add(middleware: SessionAuthenticator())
            .get(use: self.current)
    }

    /// Create new user
    func create(_ request: HBRequest) -> EventLoopFuture<UserResponse> {
        guard let createUser = try? request.decode(as: CreateUserRequest.self) else { return request.failure(.badRequest) }
        let user = User(from: createUser)
        // check if user exists and if they don't then add new user
        return User.query(on: request.db)
            .filter(\.$name == user.name)
            .first()
            .flatMapThrowing { user -> Void in
                // if user already exist throw conflict
                guard user == nil else { throw HBHTTPError(.conflict) }
                return
            }
            .flatMap { _ in
                return user.save(on: request.db)
            }
            .transform(to: UserResponse(from: user))
    }

    /// Login user and create session
    func login(_ request: HBRequest) -> EventLoopFuture<HTTPResponseStatus> {
        // get authenticated user and return
        guard let user = request.auth.get(User.self),
              let userId = user.id else { return request.failure(.unauthorized) }
        // create session lasting 1 hour
        return request.session.save(userId: userId, expiresIn: .seconds(60))
            .map { .ok }
    }

    /// Get current logged in user
    func current(_ request: HBRequest) throws -> UserResponse {
        // get authenticated user and return
        guard let user = request.auth.get(User.self) else { throw HBHTTPError(.unauthorized) }
        return UserResponse(from: user)
    }
}
