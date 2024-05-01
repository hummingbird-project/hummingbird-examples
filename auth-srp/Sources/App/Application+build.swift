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

import FluentSQLiteDriver
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent
import Logging

public protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var logLevel: Logger.Level? { get }
    var inMemoryDatabase: Bool { get }
    var migrate: Bool { get }
}

func buildApplication(_ args: AppArguments) async throws -> some ApplicationProtocol {
    let logger = {
        var logger = Logger(label: "html-form")
        logger.logLevel = args.logLevel ?? .info
        return logger
    }()
    let fluent = Fluent(logger: logger)
    // add sqlite database
    if args.inMemoryDatabase {
        fluent.databases.use(.sqlite(.memory), as: .sqlite)
    } else {
        fluent.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    }
    // add migrations
    await fluent.migrations.add(CreateUser())

    // set up persist driver before migrate
    let persist = await FluentPersistDriver(fluent: fluent)
    // Sessions
    let sessionStorage = SessionStorage(persist)

    if args.migrate || args.inMemoryDatabase {
        try await fluent.migrate()
    }

    let router = Router(context: AuthSRPRequestContext.self)
    router.middlewares.add(FileMiddleware(logger: logger))
    router.middlewares.add(LogRequestsMiddleware(.info, includeHeaders: true))
    router.addRoutes(UserController(fluent: fluent, sessionStorage: sessionStorage).routes, atPath: "/api/user")
    var application = Application(
        router: router,
        configuration: .init(address: .hostname(args.hostname, port: args.port)),
        logger: logger
    )
    application.addServices(fluent)
    return application
}

/*
 extension HBApplication {
     /// configure your application
     /// add middleware
     /// setup the encoder/decoder
     /// add your routes
     public func configure(_ arguments: AppArguments) throws {
         self.middleware.add(HBFileMiddleware(application: self))
         self.middleware.add(HBLogRequestsMiddleware(.info, includeHeaders: true))
         self.addFluent()
         // add sqlite database
         if arguments.inMemoryDatabase {
             self.fluent.databases.use(.sqlite(.memory), as: .sqlite)
         } else {
             self.fluent.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
         }
         // add migrations
         self.fluent.migrations.add(CreateUser())

         // add sessions, must be done before migrate is called if fluent is used
         self.addSessions(using: .fluent)

         // migrate
         if arguments.migrate || arguments.inMemoryDatabase == true {
             try self.fluent.migrate().wait()
         }

         self.decoder = JSONDecoder()
         self.encoder = JSONEncoder()

         UserController().addRoutes(to: self.router.group("/api/user"))
     }
 }
 */
