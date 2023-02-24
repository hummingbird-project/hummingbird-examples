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

struct AuthenticationState: HBAuthenticatable, HBResponseEncodable {
    let state: WebAuthnSessionAuthenticator.Session.State
    let user: User
}

struct WebAuthnSessionAuthenticator: HBAsyncSessionAuthenticator {
    struct Session: Codable {
        enum State: Codable {
            case none
            case registering(challenge: String)
            case authenticating(challenge: String)
            case authenticated
        }

        let state: State
        let userId: UUID

        init(state: State = .none, userId: UUID) {
            self.state = state
            self.userId = userId
        }
    }

    func getValue(from session: Session, request: HBRequest) async throws -> AuthenticationState? {
        guard let user = try await User.find(session.userId, on: request.db) else { return nil }
        return AuthenticationState(
            state: session.state,
            user: user
        )
    }
}
