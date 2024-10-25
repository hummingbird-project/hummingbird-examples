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
import HummingbirdAuth
import HummingbirdFluent
import HummingbirdRouter
import Mustache
import WebAuthn

/// Application arguments protocol. We use a protocol so we can call
/// `HBApplication.configure` inside Tests as well as in the App executable.
/// Any variables added here also have to be added to `App` in App.swift and
/// `TestArguments` in AppTest.swift
public protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var inMemoryDatabase: Bool { get }
    var certificateChain: String { get }
    var privateKey: String { get }
}

func buildApplication(_ arguments: AppArguments) async throws -> some ApplicationProtocol {
    var logger = Logger(label: "webauthn")
    logger.logLevel = .debug

    let fluent = Fluent(logger: logger)
    // add sqlite database
    if arguments.inMemoryDatabase {
        fluent.databases.use(.sqlite(.memory), as: .sqlite)
    } else {
        fluent.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    }
    await fluent.migrations.add(CreateUser())
    await fluent.migrations.add(CreateWebAuthnCredential())
    try await fluent.migrate()

    // sessions are stored in memory
    let memoryPersist = MemoryPersistDriver()

    // Verify the working directory is correct
    assert(FileManager.default.fileExists(atPath: "public/images/hummingbird.png"), "Set your working directory to the root folder of this example to get it to work")
    // load mustache template library
    let library = try await MustacheLibrary(directory: Bundle.module.resourcePath!)

    /// Authenticator storing the user
    let webAuthnSessionAuthenticator = SessionAuthenticator(
        users: UserRepository(fluent: fluent),
        context: WebAuthnRequestContext.self
    )
    let router = RouterBuilder(context: WebAuthnRequestContext.self) {
        // add logging middleware
        LogRequestsMiddleware(.info)
        // add file middleware to server HTML files
        FileMiddleware(searchForIndexHtml: true, logger: logger)
        // session loading
        SessionMiddleware(storage: memoryPersist)
        // health check endpoint
        Get("/health") { _, _ -> HTTPResponse.Status in
            return .ok
        }
        HTMLController(
            mustacheLibrary: library,
            fluent: fluent,
            webAuthnSessionAuthenticator: webAuthnSessionAuthenticator
        )
        RouteGroup("api") {
            WebAuthnController(
                webauthn: .init(
                    config: .init(
                        relyingPartyID: "localhost",
                        relyingPartyName: "Hummingbird WebAuthn example",
                        relyingPartyOrigin: "http://localhost:8080"
                    )
                ),
                fluent: fluent,
                webAuthnSessionAuthenticator: webAuthnSessionAuthenticator
            )
        }
    }

    var app = Application(router: router)
    app.addServices(fluent, memoryPersist)
    return app
}
