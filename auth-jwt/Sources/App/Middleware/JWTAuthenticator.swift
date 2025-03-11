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
import NIOFoundationCompat

struct JWTPayloadData: JWTPayload, Equatable {
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case userName = "name"
    }

    var subject: SubjectClaim
    var expiration: ExpirationClaim
    // Define additional JWT Attributes here
    var userName: String

    func verify(using algorithm: some JWTAlgorithm) async throws {
        try self.expiration.verifyNotExpired()
    }
}

struct JWTAuthenticator: AuthenticatorMiddleware, @unchecked Sendable {
    typealias Context = AppRequestContext
    let jwtKeyCollection: JWTKeyCollection
    let fluent: Fluent

    init(jwtKeyCollection: JWTKeyCollection, fluent: Fluent) {
        self.jwtKeyCollection = jwtKeyCollection
        self.fluent = fluent
    }

    func authenticate(request: Request, context: Context) async throws -> User? {
        // get JWT from bearer authorisation
        guard let jwtToken = request.headers.bearer?.token else { throw HTTPError(.unauthorized) }

        // get payload and verify its contents
        let payload: JWTPayloadData
        do {
            payload = try await self.jwtKeyCollection.verify(jwtToken, as: JWTPayloadData.self)
        } catch {
            context.logger.debug("couldn't verify token")
            throw HTTPError(.unauthorized)
        }
        // get user id and name from payload
        guard let userUUID = UUID(uuidString: payload.subject.value) else {
            context.logger.debug("Invalid JWT subject \(payload.subject.value)")
            throw HTTPError(.unauthorized)
        }
        return User(id: userUUID, name: payload.userName, passwordHash: nil)
    }
}
