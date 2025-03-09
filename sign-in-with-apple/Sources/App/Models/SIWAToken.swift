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
import Foundation
import Hummingbird

/// Database description of a user
final class SIWAToken: Model, @unchecked Sendable {
    static let schema = "siwa"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "token")
    var token: String

    @Parent(key: "user_id")
    var user: User

    init() {}

    init(id: UUID? = nil, token: String, userID: User.IDValue) {
        self.id = id
        self.token = token
        self.$user.id = userID
    }
}
