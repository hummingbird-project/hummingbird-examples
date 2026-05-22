//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
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

struct AdminController: Sendable {
    typealias Context = AppRequestContext
    let fluent: Fluent

    /// Register routes under `router.group("admin")`:
    ///
    /// - `GET /admin/users` — requires `admin` role
    func addRoutes(to group: RouterGroup<Context>) {
        group
            .add(
                middleware: BasicAuthenticator { username, _ in
                    try await User.query(on: self.fluent.db())
                        .filter(\.$name == username)
                        .first()
                }
            )
            .add(middleware: AuthorizationPolicyMiddleware(RolePolicy(.admin)))
            .get("users", use: self.listUsers)
    }

    /// Return a list of all registered users (requires `admin` role).
    func listUsers(
        _ request: Request,
        context: Context
    ) async throws -> [UserResponse] {
        let users = try await User.query(on: self.fluent.db()).all()
        return users.map { UserResponse(from: $0) }
    }
}
