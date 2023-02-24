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
import HummingbirdTLS
import WebAuthn

/// Application arguments protocol. We use a protocol so we can call
/// `HBApplication.configure` inside Tests as well as in the App executable.
/// Any variables added here also have to be added to `App` in App.swift and
/// `TestArguments` in AppTest.swift
public protocol AppArguments {
    var inMemoryDatabase: Bool { get }
    var certificateChain: String { get }
    var privateKey: String { get }
}

extension HBApplication {
    /// configure your application
    /// add middleware
    /// setup the encoder/decoder
    /// add your routes
    func configure(_ arguments: AppArguments) throws {
        // Add TLS
        try server.addTLS(tlsConfiguration: self.getTLSConfig(arguments))

        self.webauthn = .init(
            config: WebAuthnConfig(
                relyingPartyDisplayName: "Hummingbird WebAuthn example",
                relyingPartyID: "localhost",
                relyingPartyOrigin: "https://localhost:8080",
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
        self.fluent.migrations.add(CreateWebAuthnCredential())
        try self.fluent.migrate().wait()

        self.addSessions(using: .memory)

        self.router.middlewares.add(HBLogRequestsMiddleware(.info))
        self.router.middlewares.add(HBFileMiddleware(searchForIndexHtml: true, application: self))
        self.router.get("/health") { _ -> HTTPResponseStatus in
            return .ok
        }
        HBWebAuthnController().add(self.router.group("api"))
    }

    func getTLSConfig(_ arguments: AppArguments) throws -> TLSConfiguration {
        let certificateChain = try NIOSSLCertificate.fromPEMFile(arguments.certificateChain)
        let privateKey = try NIOSSLPrivateKey(file: arguments.privateKey, format: .pem)
        return TLSConfiguration.makeServerConfiguration(
            certificateChain: certificateChain.map { .certificate($0) },
            privateKey: .privateKey(privateKey)
        )
    }
}

extension HBRequest {
    var webauthn: WebAuthnManager { return self.application.webauthn }
}
