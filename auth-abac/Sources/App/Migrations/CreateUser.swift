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

struct CreateUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("user")
            .id()
            .field("name", .string, .required)
            .unique(on: "name")
            .field("password_hash", .string)
            .field("department", .string, .required)
            .field("clearance_level", .int, .required)
            .field("roles", .string, .required)
            .field("permissions", .string, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("user").delete()
    }
}
