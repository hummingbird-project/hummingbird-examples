//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2022 the Hummingbird authors
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

struct SRPSessionAuthenticator: HBSessionAuthenticator {
    enum AuthenticationState: Codable {
        case authenticating(A: String, B: String, serverSharedSecret: String)
        case authenticated
    }

    struct Session: Codable {
        let userId: UUID
        var state: AuthenticationState
    }

    typealias Value = User

    func getValue(from session: Session, request: Hummingbird.HBRequest) -> NIOCore.EventLoopFuture<User?> {
        switch session.state {
        case .authenticated:
            return User.find(session.userId, on: request.db)
        case .authenticating:
            return request.eventLoop.makeSucceededFuture(nil)
        }
    }
}
