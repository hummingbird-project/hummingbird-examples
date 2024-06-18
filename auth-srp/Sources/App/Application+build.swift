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

func buildApplication(_ args: some AppArguments) async throws -> some ApplicationProtocol {
    let logger = {
        var logger = Logger(label: "auth-srp")
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

    let router = Router(context: BasicAuthRequestContext.self)
    router.middlewares.add(RedirectMiddleware())
    router.middlewares.add(FileMiddleware(logger: logger))
    router.middlewares.add(
        LogRequestsMiddleware(
            .info,
            includeHeaders: .all(),
            redactHeaders: []
        )
    )
    router.addRoutes(
        UserController(
            fluent: fluent,
            sessionStorage: sessionStorage
        ).routes,
        atPath: "/api/user"
    )
    var application = Application(
        router: router,
        configuration: .init(address: .hostname(args.hostname, port: args.port)),
        logger: logger
    )
    application.addServices(fluent)
    return application
}
