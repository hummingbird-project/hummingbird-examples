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

/// cannot conform fluent model `User` to `HBAuthenticatable` as it is not Sendable
/// so create a copy to store in login cache
struct AuthenticatedUser: HBAuthenticatable, Codable {
    var id: UUID
    var username: String

    var publicKeyCredentialUserEntity: PublicKeyCredentialUserEntity {
        .init(id: .init(self.id.uuidString.utf8), name: self.username, displayName: self.username)
    }
}

/// Authentication state stored in login cache
enum AuthenticationSession: Sendable, Codable, HBAuthenticatable, HBResponseEncodable {
    case signedUp(user: AuthenticatedUser)
    case registering(user: AuthenticatedUser, challenge: [UInt8])
    case authenticating(challenge: [UInt8])
    case authenticated(user: AuthenticatedUser)
}

/// Session object saved to storage
enum WebAuthnSession: Codable {
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
            self = .signedUp(userId: user.id)
        case .registering(let user, let challenge):
            self = .registering(userId: user.id, encodedChallenge: challenge.base64URLEncodedString().asString())
        case .authenticated(let user):
            self = .authenticated(userId: user.id)
        }
    }

    /// return authentication state from session object
    func session(for request: HBRequest, fluent: HBFluent) async throws -> AuthenticationSession? {
        switch self {
        case .authenticating(let encodedChallenge):
            guard let challenge = URLEncodedBase64(encodedChallenge).decodedBytes else { return nil }
            return .authenticating(challenge: challenge)
        case .signedUp(let userId):
            guard let user = try await User.find(userId, on: fluent.db()) else { return nil }
            return .signedUp(user: .init(id: userId, username: user.username))
        case .registering(let userId, let encodedChallenge):
            guard let user = try await User.find(userId, on: fluent.db()) else { return nil }
            guard let challenge = URLEncodedBase64(encodedChallenge).decodedBytes else { return nil }
            return .registering(user: .init(id: userId, username: user.username), challenge: challenge)
        case .authenticated(let userId):
            guard let user = try await User.find(userId, on: fluent.db()) else { return nil }
            return .authenticated(user: .init(id: userId, username: user.username))
        }
    }
}

/// Authenticator that will return current state of authentication
struct WebAuthnSessionStateAuthenticator<Context: HBAuthRequestContextProtocol>: HBSessionAuthenticator {
    typealias Session = WebAuthnSession
    /// fluent reference
    let fluent: HBFluent
    /// container for session objects
    let sessionStorage: HBSessionStorage

    func getValue(from session: Session, request: HBRequest, context: Context) async throws -> AuthenticationSession? {
        return try await session.session(for: request, fluent: self.fluent)
    }
}

/// Authenticator that will return an authenticated user from a WebAuthnSession
struct WebAuthnSessionAuthenticator<Context: HBAuthRequestContextProtocol>: HBSessionAuthenticator {
    typealias Session = WebAuthnSession

    /// fluent reference
    let fluent: HBFluent
    /// container for session objects
    let sessionStorage: HBSessionStorage

    func getValue(from session: Session, request: HBRequest, context: Context) async throws -> AuthenticatedUser? {
        guard case .authenticated(let userId) = session else { return nil }
        if let user = try await User.find(userId, on: self.fluent.db()) {
            return AuthenticatedUser(id: userId, username: user.username)
        } else {
            return nil
        }
    }
}
