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
import HummingbirdFluent
import HummingbirdFoundation
import HummingbirdRedis

func runApp(_ arguments: HummingbirdArguments) throws {
    let app = HBApplication(configuration: .init(address: .hostname(arguments.hostname, port: arguments.port)))

    // add JSON encoder/decoder as we are reading and writing JSON
    app.encoder = JSONEncoder()
    app.decoder = JSONDecoder()

    // add Redis
    try app.addRedis(configuration: .init(hostname: "localhost", port: 6379))
    // add Fluent
    app.addFluent()
    // add sqlite database
    app.fluent.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    // add migrations
    app.fluent.migrations.add(CreateUser())
    app.fluent.migrations.add(CreateSession())
    // migrate
    if arguments.migrate {
        try app.fluent.migrate().wait()
    }

    // add logging middleware
    app.middleware.add(HBLogRequestsMiddleware(.debug))

    // routes
    app.router.get("/") { _ in
        return "Hello"
    }

    let userController = UserController()
    userController.addRoutes(to: app.router.group("user"))

    app.start()
    app.wait()
}
