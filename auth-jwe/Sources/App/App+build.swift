//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2026 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Configuration
import FluentSQLiteDriver
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent
import Logging
import ServiceLifecycle

/// Request context carrying the authenticated user identity.
typealias AppRequestContext = BasicAuthRequestContext<User>

///  Build application
/// - Parameters:
///   - reader: configuration reader
///   - keys: token keys; tests inject fixed keys, otherwise the demo keys are used
func buildApplication(reader: ConfigReader, keys: TokenKeys? = nil) async throws -> some ApplicationProtocol {
    let logger = {
        var logger = Logger(label: "auth-jwe")
        // Defaults to debug so the "token rejected" traces are visible when running the example.
        logger.logLevel = reader.string(forKey: "log.level", as: Logger.Level.self, default: .debug)
        return logger
    }()

    let fluent = Fluent(logger: logger)
    let inMemoryDatabase = reader.bool(forKey: "db.inMemory", default: true)
    if inMemoryDatabase {
        fluent.databases.use(.sqlite(.memory), as: .sqlite)
    } else {
        fluent.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    }
    await fluent.migrations.add(CreateUser())
    if inMemoryDatabase || reader.bool(forKey: "db.migrate", default: false) {
        try await fluent.migrate()
    }

    let router = try buildRouter(
        fluent: fluent,
        keys: keys ?? TokenKeys(),
        issuer: reader.string(forKey: "jwt.issuer", default: "auth-jwe-example"),
        audience: reader.string(forKey: "jwt.audience", default: "hummingbird-clients")
    )
    var app = Application(
        router: router,
        configuration: ApplicationConfiguration(reader: reader.scoped(to: "http")),
        logger: logger
    )
    app.addServices(fluent)
    return app
}

/// Build router
func buildRouter(fluent: Fluent, keys: TokenKeys, issuer: String, audience: String) throws -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    router.addMiddleware {
        LogRequestsMiddleware(.info)
    }
    UserController(keys: keys, fluent: fluent, issuer: issuer, audience: audience)
        .addRoutes(to: router.group("user"))
    // Routes behind encrypted-token authentication.
    router.group("auth")
        .add(middleware: JWEAuthenticator(keys: keys, audience: audience))
        .get("/") { _, context -> [String: String] in
            let user = try context.requireIdentity()
            return [
                "username": user.username,
                "email": user.email ?? "",
                "role": user.role ?? "",
            ]
        }
    return router
}
