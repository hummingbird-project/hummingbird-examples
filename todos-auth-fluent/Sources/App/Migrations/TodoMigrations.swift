//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import FluentKit

struct CreateTodo: AsyncMigration {
    func prepare(on database: Database) async throws {
        return try await database.schema("todos")
            .id()
            .field("title", .string, .required)
            .field("owner_id", .uuid, .required, .references("user", "id"))
            .field("completed", .bool, .required)
            .field("url", .string)
            .create()
    }

    func revert(on database: Database) async throws {
        return try await database.schema("todos").delete()
    }
}
