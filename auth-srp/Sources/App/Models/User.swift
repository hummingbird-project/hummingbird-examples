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
import HummingbirdAuth

/// Database description of a user
final class User: Model, Authenticatable, @unchecked Sendable {
    static let schema = "user"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "salt")
    var salt: String

    @Field(key: "verifier")
    var verifier: String

    init() {}

    init(id: UUID? = nil, name: String, salt: String, verifier: String) {
        self.id = id
        self.name = name
        self.salt = salt
        self.verifier = verifier
    }
}
