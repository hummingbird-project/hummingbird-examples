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

struct WebAuthnSessionAuthenticator: HBAsyncSessionAuthenticator {
    enum Session: Codable {
        case registering(challenge: String)
        case authenticating(challenge: String)
        case authenticated(userId: UUID)
    }

    func getValue(from session: Session, request: HBRequest) async throws -> User? {
        if case .authenticated(let userId) = session {
            return try await User.find(userId, on: request.db)
        }
        return nil
    }
}
