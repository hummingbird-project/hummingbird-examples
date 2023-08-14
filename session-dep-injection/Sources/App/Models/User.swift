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

    @Field(key: "name")
    var name: String

    @Field(key: "password-hash")
    var passwordHash: String

    internal init() {}

    internal init(id: UUID? = nil, name: String, passwordHash: String) {
        self.id = id
        self.name = name
        self.passwordHash = passwordHash
    }

    internal init(from userRequest: CreateUserRequest) {
        self.id = nil
        self.name = userRequest.name
        self.passwordHash = Bcrypt.hash(userRequest.password, cost: 12)
    }
}

/// Create user request object decoded from HTTP body
struct CreateUserRequest: Decodable {
    let name: String
    let password: String

    internal init(name: String, password: String) {
        self.name = name
        self.password = password
    }
}

/// User encoded into HTTP response
struct UserResponse: HBResponseCodable {
    let id: UUID?
    let name: String

    internal init(id: UUID?, name: String) {
        self.id = id
        self.name = name
    }

    internal init(from user: User) {
        self.id = user.id
        self.name = user.name
    }
}
