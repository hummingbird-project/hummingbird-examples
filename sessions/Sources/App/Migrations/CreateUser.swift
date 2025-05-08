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

struct CreateUser: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        // The `schema` function is used to create a new schema
        // The schema is a collection of fields that are used to define the structure of the table
        return database.schema("user")
            .id() // The ID has a default name depending on the database
            // Required indicates that the field is not optional in the model
            .field("name", .string, .required)
            // The passwordHash in the model was optional, so we omit "required"
            .field("password-hash", .string)
            // Creates the table in the database
            .create()
    }

    // The inverse of the `prepare` function is the `revert` function
    // Essentially an "undo" of the prepare function in this migration
    func revert(on database: Database) -> EventLoopFuture<Void> {
        // The inverse of the `create` function is the `delete` function
        return database.schema("user").delete()
    }
}
