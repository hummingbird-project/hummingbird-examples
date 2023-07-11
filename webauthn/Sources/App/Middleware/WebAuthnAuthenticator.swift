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
import HummingbirdAuth
import WebAuthn

/// Authentication state
enum AuthenticationSession: Codable, HBAuthenticatable, HBResponseEncodable {
    case signedUp(user: User)
    case registering(user: User, challenge: [UInt8])
    case authenticating(challenge: [UInt8])
    case authenticated(user: User)
}

/// Authenticator that will return current state of authentication
struct WebAuthnSessionStateAuthenticator: HBAsyncSessionAuthenticator {
    /// Session object saved to storage
    enum Session: Codable {
        case signedUp(userId: UUID)
        case registering(userId: UUID, encodedChallenge: String)
        case authenticating(encodedChallenge: String)
        case authenticated(userId: UUID)

        /// init session object from authentication state
        init(from session: AuthenticationSession) {
            switch session {
            case .authenticating(let challenge):
                self = .authenticating(encodedChallenge: challenge.base64URLEncodedString().asString())
            case .signedUp(let user):
                self = .signedUp(userId: user.id!)
            case .registering(let user, let challenge):
                self = .registering(userId: user.id!, encodedChallenge: challenge.base64URLEncodedString().asString())
            case .authenticated(let user):
                self = .authenticated(userId: user.id!)
            }
        }

        /// return authentication state from session object
        func session(for request: HBRequest) async throws -> AuthenticationSession? {
            switch self {
            case .authenticating(let encodedChallenge):
                guard let challenge = URLEncodedBase64(encodedChallenge).decodedBytes else { return nil }
                return .authenticating(challenge: challenge)
            case .signedUp(let userId):
                guard let user = try await User.find(userId, on: request.db) else { return nil }
                return .signedUp(user: user)
            case .registering(let userId, let encodedChallenge):
                guard let user = try await User.find(userId, on: request.db) else { return nil }
                guard let challenge = URLEncodedBase64(encodedChallenge).decodedBytes else { return nil }
                return .registering(user: user, challenge: challenge)
            case .authenticated(let userId):
                guard let user = try await User.find(userId, on: request.db) else { return nil }
                return .authenticated(user: user)
            }
        }
    }

    func getValue(from session: Session, request: HBRequest) async throws -> AuthenticationSession? {
        return try await session.session(for: request)
    }
}

/// Authenticator that will return an authenticated user
struct WebAuthnSessionAuthenticator: HBAsyncSessionAuthenticator {
    typealias Session = WebAuthnSessionStateAuthenticator.Session
    func getValue(from session: Session, request: HBRequest) async throws -> User? {
        guard case .authenticated(let userId) = session else { return nil }
        return try await User.find(userId, on: request.db)
    }
}
