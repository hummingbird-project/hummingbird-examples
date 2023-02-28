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

enum AuthenticationSession: Codable, HBAuthenticatable, HBResponseEncodable {
    case signedUp(user: User)
    case registering(user: User, challenge: EncodedBase64)
    case authenticating(challenge: EncodedBase64)
    case authenticated(user: User)
}

struct WebAuthnSessionAuthenticator: HBAsyncSessionAuthenticator {
    enum Session: Codable {
        case signedUp(userId: UUID)
        case registering(userId: UUID, challenge: EncodedBase64)
        case authenticating(challenge: EncodedBase64)
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
