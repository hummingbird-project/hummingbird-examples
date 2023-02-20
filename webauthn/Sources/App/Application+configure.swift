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
import Foundation
import Hummingbird
import HummingbirdFluent
import HummingbirdFoundation
import WebAuthn

/// Application arguments protocol. We use a protocol so we can call
/// `HBApplication.configure` inside Tests as well as in the App executable.
/// Any variables added here also have to be added to `App` in App.swift and
/// `TestArguments` in AppTest.swift
public protocol AppArguments {
    var inMemoryDatabase: Bool { get }
}

extension HBApplication {
    /// configure your application
    /// add middleware
    /// setup the encoder/decoder
    /// add your routes
    func configure(_ arguments: AppArguments) throws {
        self.webauthn = .init(
            config: WebAuthnConfig(
                relyingPartyDisplayName: "Hummingbird WebAuthn example",
                relyingPartyID: "hummingbird.com",
                relyingPartyOrigin: "https://hummingbird.com",
                timeout: 600
            )
        )

        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()

        self.addFluent()
        // add sqlite database
        if arguments.inMemoryDatabase {
            self.fluent.databases.use(.sqlite(.memory), as: .sqlite)
        } else {
            self.fluent.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
        }
        // add migrations
        self.fluent.migrations.add(CreateUser())

        self.addSessions(using: .memory)

        self.router.get("/health") { _ -> HTTPResponseStatus in
            return .ok
        }
    }
}

extension HBRequest {
    var webauthn: WebAuthnManager { return self.application.webauthn }
}
