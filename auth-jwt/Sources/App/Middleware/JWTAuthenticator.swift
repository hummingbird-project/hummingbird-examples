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
import JWTKit
import NIOFoundationCompat

struct JWTPayloadData: JWTPayload, Equatable, HBAuthenticatable {
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
    }

    var subject: SubjectClaim
    var expiration: ExpirationClaim
    // Define additional JWT Attributes here

    func verify(using signer: JWTSigner) throws {
        try self.expiration.verifyNotExpired()
    }
}

struct JWTAuthenticator: HBAsyncAuthenticator {
    let jwtSigners: JWTSigners

    init() {
        self.jwtSigners = JWTSigners()
    }

    init(_ signer: JWTSigner, kid: JWKIdentifier? = nil) {
        self.jwtSigners = JWTSigners()
        self.jwtSigners.use(signer, kid: kid)
    }

    init(jwksData: ByteBuffer) throws {
        let jwks = try JSONDecoder().decode(JWKS.self, from: jwksData)
        self.jwtSigners = JWTSigners()
        try self.jwtSigners.use(jwks: jwks)
    }

    func useSigner(_ signer: JWTSigner, kid: JWKIdentifier) {
        self.jwtSigners.use(signer, kid: kid)
    }

    func authenticate(request: HBRequest) async throws -> User? {
        // get JWT from bearer authorisation
        guard let jwtToken = request.authBearer?.token else { throw HBHTTPError(.unauthorized) }

        let payload: JWTPayloadData
        do {
            payload = try self.jwtSigners.verify(jwtToken, as: JWTPayloadData.self)
        } catch {
            request.logger.debug("couldn't verify token")
            throw HBHTTPError(.unauthorized)
        }
        // check if user exists and return if it exists
        if let existingUser = try await User.query(on: request.db)
            .filter(\.$name == payload.subject.value)
            .first()
        {
            return existingUser
        }

        // if user doesn't exist then JWT was created by a another service and we should create a user
        // for it, with no associated password
        let user = User(id: nil, name: payload.subject.value, passwordHash: nil)
        try await user.save(on: request.db)

        return user
    }
}
