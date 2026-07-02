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
import Foundation
import HummingbirdBasicAuth
import JWSETKit

/// A user of this service, stored in memory. `email` and `role` are private
/// claims: they travel inside the encrypted token, never visible to the client.
struct User: PasswordAuthenticatable {
    let username: String
    let passwordHash: String?
    var email: String?
    var role: String?
}

extension User {
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
                $0 = $0.addBase(
                    issuer: issuer, audience: [audience],
                    subject: self.username, expiresIn: expiresIn
                )
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
