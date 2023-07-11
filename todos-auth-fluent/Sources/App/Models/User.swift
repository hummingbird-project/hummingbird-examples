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

/// Database description of a user
final class User: Model, HBAuthenticatable {
    static let schema = "user"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "email")
    var email: String

    @Field(key: "name")
    var name: String

    @Field(key: "password")
    var passwordHash: String

    @Children(for: \.$owner)
    var todos: [Todo]

    internal init() {}

    internal init(id: UUID? = nil, name: String, email: String, passwordHash: String) {
        self.id = id
        self.name = name
        self.email = email
        self.passwordHash = passwordHash
    }

    internal init(from userRequest: CreateUserRequest) {
        self.id = nil
        self.name = userRequest.name
        self.passwordHash = Bcrypt.hash(userRequest.password, cost: 12)
    }
}

extension User {
    static func create(name: String, email: String, password: String, request: HBRequest) async throws -> User {
        // check if user exists and if they don't then add new user
        let existingUser = try await User.query(on: request.db)
            .filter(\.$name == name)
            .first()
        // if user already exist throw conflict
        guard existingUser == nil else { throw HBHTTPError(.conflict) }

        let passwordHash = Bcrypt.hash(password, cost: 12)
        let user = User(name: name, email: email, passwordHash: passwordHash)
        try await user.save(on: request.db)
        return user
    }

    static func login(email: String, password: String, request: HBRequest) async throws -> User? {
        // check if user exists in the database and then verify the entered password
        // against the one stored in the database. If it is correct then login in user
        let user = try await User.query(on: request.db)
            .filter(\.$email == email)
            .first()
        guard let user = user else { return nil }
        guard Bcrypt.verify(password, hash: user.passwordHash) else { return nil }
        return user
    }
}

/// Create user request object decoded from HTTP body
struct CreateUserRequest: Decodable {
    let name: String
    let email: String
    let password: String

    internal init(name: String, email: String, password: String) {
        self.name = name
        self.email = email
        self.password = password
    }
}

/// User encoded into HTTP response
struct UserResponse: HBResponseCodable {
    let id: UUID?

    internal init(id: UUID?) {
        self.id = id
    }

    internal init(from user: User) {
        self.id = user.id
    }
}
