//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
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
import HummingbirdFluent
import WebAuthn

/// Authentication state stored in login cache
enum AuthenticationSession: Sendable, Codable, Authenticatable, ResponseEncodable {
    case signedUp(user: User)
    case registering(user: User, challenge: [UInt8])
    case authenticating(challenge: [UInt8])
    case authenticated(user: User)
}

/// Session object saved to storage
enum WebAuthnSession: Codable {
    case signedUp(userId: UUID)
    case registering(userId: UUID, encodedChallenge: String)
    case authenticating(encodedChallenge: String)
    case authenticated(userId: UUID)

    /// init session object from authentication state
    init(from session: AuthenticationSession) throws {
        switch session {
        case .authenticating(let challenge):
            self = .authenticating(encodedChallenge: challenge.base64URLEncodedString().asString())
        case .signedUp(let user):
            self = try .signedUp(userId: user.requireID())
        case .registering(let user, let challenge):
            self = try .registering(userId: user.requireID(), encodedChallenge: challenge.base64URLEncodedString().asString())
        case .authenticated(let user):
            self = try .authenticated(userId: user.requireID())
        }
    }

    /// return authentication state from session object
    func session(fluent: Fluent) async throws -> AuthenticationSession? {
        switch self {
        case .authenticating(let encodedChallenge):
            guard let challenge = URLEncodedBase64(encodedChallenge).decodedBytes else { return nil }
            return .authenticating(challenge: challenge)
        case .signedUp(let userId):
            guard let user = try await User.find(userId, on: fluent.db()) else { return nil }
            return .signedUp(user: user)
        case .registering(let userId, let encodedChallenge):
            guard let user = try await User.find(userId, on: fluent.db()) else { return nil }
            guard let challenge = URLEncodedBase64(encodedChallenge).decodedBytes else { return nil }
            return .registering(user: user, challenge: challenge)
        case .authenticated(let userId):
            guard let user = try await User.find(userId, on: fluent.db()) else { return nil }
            return .authenticated(user: user)
        }
    }
}
