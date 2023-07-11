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
    enum Session: Codable {
        case signedUp(userId: UUID)
        case registering(userId: UUID, challenge: [UInt8])
        case authenticating(challenge: [UInt8])
        case authenticated(userId: UUID)
    }

    func getValue(from session: Session, request: HBRequest) async throws -> AuthenticationSession? {
        switch session {
        case .authenticating(let challenge):
            return .authenticating(challenge: challenge)
        case .signedUp(let userId):
            guard let user = try await User.find(userId, on: request.db) else { return nil }
            return .signedUp(user: user)
        case .registering(let userId, let challenge):
            guard let user = try await User.find(userId, on: request.db) else { return nil }
            return .registering(user: user, challenge: challenge)
        case .authenticated(let userId):
            guard let user = try await User.find(userId, on: request.db) else { return nil }
            return .authenticated(user: user)
        }
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
