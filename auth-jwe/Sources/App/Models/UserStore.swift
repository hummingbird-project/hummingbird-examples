//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2026 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HummingbirdBcrypt

/// In-memory user store with demo credentials.
struct UserStore {
    private let users: [String: User]

    init(users: [String: User]) {
        self.users = users
    }

    static func demo() -> UserStore {
        .init(users: [
            "alice": User(
                username: "alice",
                passwordHash: Bcrypt.hash("alice-password", cost: 8),
                email: "alice@example.com",
                role: "admin"
            ),
        ])
    }

    func user(named username: String) -> User? {
        self.users[username]
    }
}
