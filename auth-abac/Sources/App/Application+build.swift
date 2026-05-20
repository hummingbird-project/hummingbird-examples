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
import HummingbirdFluent
import Logging

protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var inMemoryDatabase: Bool { get }
    var migrate: Bool { get }
    /// Hour range during which document deletion is permitted (environment attribute).
    /// Production: `9..<17`. Tests: `0..<24` (always allowed).
    var allowedDeletionHours: Range<Int> { get }
}

func buildApplication(_ args: AppArguments) async throws -> some ApplicationProtocol {
    let logger = {
        var logger = Logger(label: "auth-abac")
        logger.logLevel = .debug
        return logger
    }()
    let fluent = Fluent(logger: logger)
    if args.inMemoryDatabase {
        fluent.databases.use(.sqlite(.memory), as: .sqlite)
    } else {
        fluent.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    }

    await fluent.migrations.add(CreateUser())
    await fluent.migrations.add(CreateDocument())

    if args.migrate || args.inMemoryDatabase {
        try await fluent.migrate()
    }

    let router = Router(context: AppRequestContext.self)
    router.add(middleware: LogRequestsMiddleware(.debug))

    UserController(fluent: fluent).addRoutes(to: router.group("user"))
    DocumentController(
        fluent: fluent,
        allowedDeletionHours: args.allowedDeletionHours
    ).addRoutes(to: router.group("documents"))

    var app = Application(
        router: router,
        configuration: .init(
            address: .hostname(args.hostname, port: args.port),
            serverName: "auth-abac"
        ),
        logger: logger
    )
    app.addServices(fluent)
    return app
}
