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
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent

struct SRPSessionAuthenticator: SessionMiddleware {
    typealias Context = BasicAuthRequestContext
    let fluent: Fluent
    let sessionStorage: SessionStorage

    enum AuthenticationState: Codable {
        case authenticating(A: String, B: String, serverSharedSecret: String)
        case authenticated
    }

    struct Session: Codable {
        let userId: UUID
        var state: AuthenticationState
    }

    typealias Value = User

    func getValue(from session: Session, request: Request, context: Context) async throws -> User? {
        switch session.state {
        case .authenticated:
            return try await User.find(session.userId, on: self.fluent.db())
        case .authenticating:
            return nil
        }
    }
}
