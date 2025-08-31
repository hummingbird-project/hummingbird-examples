//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2025 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import FluentKit

struct CreateSIWAToken: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("siwa")
            .id()
            .field("token", .string, .required)
            .field("user_id", .uuid, .required, .references("user", "id"))
            .unique(on: "user_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("siwa").delete()
    }
}
