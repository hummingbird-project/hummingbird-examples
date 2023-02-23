//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import FluentSQLiteDriver
import HummingbirdAuth
import HummingbirdFluent
import WebAuthn

final class User: Model, HBAuthenticatable {
    static let schema = "user"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "webAuthnId")
    var webAuthnId: String

    @Field(key: "publicKey")
    var publicKey: String

    init() {}

    init(from credential: Credential) {
        self.webAuthnId = credential.id
        self.publicKey = credential.publicKey.base64EncodedString()
    }
}
