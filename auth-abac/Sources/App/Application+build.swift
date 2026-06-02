import FluentKit
import FluentSQLiteDriver
import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdCompression
import HummingbirdFluent
import Logging
import Mustache

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

    // Create FluentPersistDriver *before* migrating so its _hb_persist_ table migration
    // is registered and included when fluent.migrate() runs.
    let fluentPersist = await FluentPersistDriver(fluent: fluent)

    // Always migrate on startup — Fluent tracks applied migrations and skips already-run ones.
    try await fluent.migrate()

    // Load mustache templates from bundle resources
    let library = try await MustacheLibrary(directory: Bundle.module.resourcePath!)

    let router = Router(context: AppRequestContext.self)
    router.addMiddleware {
        LogRequestsMiddleware(.debug)
        ResponseCompressionMiddleware(minimumResponseSizeToCompress: 256)
        FileMiddleware(logger: logger)
        SessionMiddleware(storage: fluentPersist)
    }

    // Web UI routes
    WebController(mustacheLibrary: library, fluent: fluent).addRoutes(to: router)

    // API routes (unchanged)
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
    app.addServices(fluent, fluentPersist)
    return app
}
