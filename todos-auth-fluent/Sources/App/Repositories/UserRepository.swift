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

struct UserRepository: UserSessionRepository, UserPasswordRepository {
    typealias User = App.User
    typealias Session = UUID

    let fluent: Fluent

    func getUser(from session: UUID, context: UserRepositoryContext) async throws -> User? {
        try await User.find(session, on: self.fluent.db())
    }

    func getUser(named email: String, context: UserRepositoryContext) async throws -> User? {
        try await User.query(on: self.fluent.db())
            .filter(\.$email == email)
            .first()
    }
}
