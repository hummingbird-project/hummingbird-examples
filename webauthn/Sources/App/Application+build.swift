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
import HummingbirdMustache
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

func buildApplication(_ arguments: AppArguments) async throws -> some HBApplicationProtocol {
    var logger = Logger(label: "webauthn")
    logger.logLevel = .debug

    let fluent = HBFluent(logger: logger)
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
    let memoryPersist = HBMemoryPersistDriver()
    let sessionStorage = HBSessionStorage(memoryPersist)

    // load mustache template library
    let library = try HBMustacheLibrary(directory: "templates")
    assert(library.getTemplate(named: "home") != nil, "Set your working directory to the root folder of this example to get it to work")

    // create router
    let router = HBRouter(context: HBAuthRequestContext.self)
    // add logging middleware
    router.middlewares.add(HBLogRequestsMiddleware(.info))
    // add file middleware to server HTML files
    router.middlewares.add(HBFileMiddleware(searchForIndexHtml: true, logger: logger))
    // add health check endpoint
    router.get("/health") { _, _ -> HTTPResponse.Status in
        return .ok
    }

    // Add HTML routes
    HTMLController(mustacheLibrary: library, fluent: fluent, sessionStorage: sessionStorage).addRoutes(to: router.group())
    // Add WebAuthn routes
    HBWebAuthnController(
        webauthn: .init(
            config: .init(
                relyingPartyID: "localhost",
                relyingPartyName: "Hummingbird WebAuthn example",
                relyingPartyOrigin: "http://localhost:8080"
            )
        ),
        fluent: fluent,
        sessionStorage: sessionStorage
    ).add(to: router.group("api"))

    var app = HBApplication(router: router)
    app.addServices(fluent, memoryPersist)
    return app
}

/* extension HBApplication {
     /// configure your application
     /// add middleware
     /// setup the encoder/decoder
     /// add your routes
     func configure(_ arguments: AppArguments) throws {
         // Add TLS
         // try server.addTLS(tlsConfiguration: self.getTLSConfig(arguments))

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

         // load mustache template library
         let library = try HBMustacheLibrary(directory: "templates")
         assert(library.getTemplate(named: "home") != nil, "Set your working directory to the root folder of this example to get it to work")

         // Add WebAuthn routes
         HTMLController(mustacheLibrary: library).addRoutes(to: self.router)
         // Add WebAuthn routes
         HBWebAuthnController(
             webauthn: .init(
                 config: .init(
                     relyingPartyID: "localhost",
                     relyingPartyName: "Hummingbird WebAuthn example",
                     relyingPartyOrigin: "http://localhost:8080"
                 )
             )
         ).add(to: self.router.group("api"))
     }
 }
 */
