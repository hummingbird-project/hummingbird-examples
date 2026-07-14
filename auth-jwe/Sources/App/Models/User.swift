//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2026 the Hummingbird authors
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
import HummingbirdBasicAuth
import HummingbirdBcrypt
import JWSETKit
import NIOPosix

/// Database description of a user. `email` and `role` are private claims: they
/// travel inside the encrypted token and are never visible to the client.
final class User: Model, PasswordAuthenticatable, @unchecked Sendable {
    static let schema = "user"

    @ID(key: .id) var id: UUID?
    @Field(key: "name") var name: String
    @OptionalField(key: "password-hash") var passwordHash: String?
    @OptionalField(key: "email") var email: String?
    @OptionalField(key: "role") var role: String?

    init() {}

    init(id: UUID? = nil, name: String, passwordHash: String?, email: String? = nil, role: String? = nil) {
        self.id = id
        self.name = name
        self.passwordHash = passwordHash
        self.email = email
        self.role = role
    }

    init(from request: CreateUserRequest) async throws {
        self.id = nil
        self.name = request.name
        self.email = request.email
        self.role = request.role
        if let password = request.password {
            self.passwordHash = try await NIOThreadPool.singleton.runIfActive { Bcrypt.hash(password, cost: 12) }
        } else {
            self.passwordHash = nil
        }
    }
}

extension User {
    var username: String {
        self.name
    }

    /// Sign these claims (ES256), then encrypt the JWS into a JWE so the
    /// private claims stay confidential.
    func issueNestedToken(
        keys: TokenKeys,
        issuer: String,
        audience: String,
        expiresIn: TimeInterval = 60 * 60
    ) throws -> String {
        let jwt = try JSONWebToken(
            payload: .init {
                $0 = $0.addBase(issuer: issuer, audience: [audience], subject: self.name, expiresIn: expiresIn)
                $0.email = self.email
                $0["role"] = self.role
            },
            using: keys.signing
        )

        var header = JOSEHeader()
        header.contentType = .jwt // mark the plaintext as a nested JWT
        let jwe = try JSONWebEncryption(
            protected: header,
            content: Data(compact: jwt),
            keyEncryptingAlgorithm: .ecdhEphemeralStaticAESKeyWrap256,
            keyEncryptionKey: keys.encryptionPublicKey,
            contentEncryptionAlgorithm: .aesEncryptionGCM256
        )
        return try String(jwe)
    }
}

/// Create-user request decoded from the HTTP body.
struct CreateUserRequest: Decodable {
    let name: String
    let password: String?
    let email: String?
    let role: String?
}

/// User encoded into the HTTP response.
struct UserResponse: ResponseCodable {
    let id: UUID?
    let name: String

    init(from user: User) {
        self.id = user.id
        self.name = user.name
    }
}
