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
import HummingbirdBasicAuth
import HummingbirdFluent

struct UserRepository<Context: AuthRequestContext & RequestContext>: SessionUserRepository, PasswordUserRepository {
    typealias User = App.User
    typealias Session = UUID

    let fluent: Fluent

    func getUser(from session: UUID, context: Context) async throws -> User? {
        try await User.find(session, on: self.fluent.db())
    }

    func getUser(named email: String) async throws -> User? {
        try await User.query(on: self.fluent.db())
            .filter(\.$email == email)
            .first()
    }
}
