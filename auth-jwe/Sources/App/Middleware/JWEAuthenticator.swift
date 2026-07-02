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
import Hummingbird
import HummingbirdAuth
import JWSETKit

/// Decrypts a JWE bearer token and verifies the nested JWT.
struct JWEAuthenticator: AuthenticatorMiddleware {
    typealias Context = AppRequestContext
    let keys: TokenKeys
    let audience: String

    func authenticate(request: Request, context: Context) async throws -> User? {
        // `HTTPError` is ambiguous between Hummingbird and JWSETKit; qualify ours.
        guard let token = request.headers.bearer?.token else {
            throw Hummingbird.HTTPError(.unauthorized)
        }
        do {
            let jwe = try JSONWebEncryption(from: token)
            let jwt = try jwe.openNestedToken(keys: self.keys, audience: self.audience)
            guard let subject = jwt.payload.subject else {
                throw Hummingbird.HTTPError(.unauthorized)
            }
            return User(
                username: subject,
                passwordHash: nil,
                email: jwt.payload.email,
                role: jwt.payload["role"]
            )
        } catch let error as Hummingbird.HTTPError {
            throw error
        } catch {
            context.logger.debug("token rejected: \(error)")
            throw Hummingbird.HTTPError(.unauthorized)
        }
    }
}

extension JSONWebEncryption {
    /// Decrypt a nested token and verify the inner JWT, returning it.
    func openNestedToken(keys: TokenKeys, audience: String) throws -> JSONWebToken {
        // Only accept tokens that declare a nested JWT payload.
        guard header.protected.contentType == .jwt else {
            throw Hummingbird.HTTPError(.unauthorized)
        }
        let plaintext = try decrypt(using: keys.encryption)
        let jwt = try JSONWebToken(from: plaintext)
        try jwt.verify(using: keys.signingPublicKey, for: audience)
        return jwt
    }
}
