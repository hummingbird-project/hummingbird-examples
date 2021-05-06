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
import Foundation
import Hummingbird
import HummingbirdAuth

/// Database description of a session
final class SessionData: Model {
    static let schema = "session"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user-id")
    var user: User

    @Field(key: "expires")
    var expires: Date

    internal init() {}

    internal init(id: UUID? = nil, userId: UUID, expires: Date) {
        self.id = id
        self.$user.id = userId
        self.expires = expires
    }
}
