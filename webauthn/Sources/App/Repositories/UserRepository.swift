//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
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

struct UserRepository: UserSessionRepository {
    let fluent: Fluent

    func getUser(from session: WebAuthnSession, context: UserRepositoryContext) async throws -> User? {
        guard case .authenticated(let userId) = session else { return nil }
        return try await User.find(userId, on: self.fluent.db())
    }
}
