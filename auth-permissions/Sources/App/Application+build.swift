//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import FluentKit
import FluentSQLiteDriver
import Hummingbird
import HummingbirdAuth
import HummingbirdBasicAuth
import HummingbirdFluent
import Logging

protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var inMemoryDatabase: Bool { get }
    var migrate: Bool { get }
}

typealias AppRequestContext = BasicAuthRequestContext<User>

func buildApplication(_ args: AppArguments) async throws -> some ApplicationProtocol {
    let logger = {
        var logger = Logger(label: "auth-permissions")
        logger.logLevel = .debug
        return logger
    }()
    let fluent = Fluent(logger: logger)
    // Add SQLite database
    if args.inMemoryDatabase {
        fluent.databases.use(.sqlite(.memory), as: .sqlite)
    } else {
        fluent.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    }
    // Add migrations
    await fluent.migrations.add(CreateUser())
    await fluent.migrations.add(CreatePost())
    // Migrate if requested
    if args.migrate || args.inMemoryDatabase {
        try await fluent.migrate()
    }

    // Create router
    let router = Router(context: AppRequestContext.self)
    router.add(middleware: LogRequestsMiddleware(.debug))

    // Register controllers
    UserController(fluent: fluent).addRoutes(to: router.group("user"))
    PostController(fluent: fluent).addRoutes(to: router.group("posts"))
    AdminController(fluent: fluent).addRoutes(to: router.group("admin"))

    var app = Application(
        router: router,
        configuration: .init(
            address: .hostname(args.hostname, port: args.port),
            serverName: "auth-permissions"
        ),
        logger: logger
    )
    app.addServices(fluent)
    return app
}
