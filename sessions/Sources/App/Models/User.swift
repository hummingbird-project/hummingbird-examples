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

import Bcrypt
import FluentKit
import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdBasicAuth
import NIOPosix

/// Database description of a user
final class User: Model, BasicAuthenticationUser, @unchecked Sendable {
    static let schema = "user"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "password-hash")
    var passwordHash: String?

    init() {}

    init(id: UUID? = nil, name: String, passwordHash: String) {
        self.id = id
        self.name = name
        self.passwordHash = passwordHash
    }

    init(from userRequest: CreateUserRequest) async throws {
        self.id = nil
        self.name = userRequest.name

        // Do Bcrypt hash on a separate thread to not block the general task executor
        self.passwordHash = try await NIOThreadPool.singleton.runIfActive { Bcrypt.hash(userRequest.password, cost: 12) }
    }
}

extension User {
    var username: String { self.name }
}

/// Create user request object decoded from HTTP body
struct CreateUserRequest: Codable {
    let name: String
    let password: String

    init(name: String, password: String) {
        self.name = name
        self.password = password
    }
}

/// User encoded into HTTP response
struct UserResponse: ResponseCodable {
    let id: UUID
    let name: String

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    init(from user: User) throws {
        self.id = try user.requireID()
        self.name = user.name
    }
}
