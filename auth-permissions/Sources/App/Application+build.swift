import FluentKit
import FluentSQLiteDriver
import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdBasicAuth
import HummingbirdCompression
import HummingbirdFluent
import Logging
import Mustache

protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var inMemoryDatabase: Bool { get }
    var migrate: Bool { get }
}

func buildApplication(_ args: AppArguments) async throws -> some ApplicationProtocol {
    let logger = {
        var logger = Logger(label: "auth-permissions")
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
    await fluent.migrations.add(CreatePost())

    // Create FluentPersistDriver *before* migrating so its _hb_persist_ table migration
    // is registered and included when fluent.migrate() runs.
    let fluentPersist = await FluentPersistDriver(fluent: fluent)

    // Always migrate on startup — Fluent tracks applied migrations and skips already-run ones.
    try await fluent.migrate()

    // Load mustache templates from bundle resources
    let library = try await MustacheLibrary(directory: Bundle.module.resourcePath!)

    let userRepository = UserRepository(fluent: fluent)
    let sessionAuthenticator = SessionAuthenticator(users: userRepository, context: AppRequestContext.self)

    let router = Router(context: AppRequestContext.self)
    router.addMiddleware {
        LogRequestsMiddleware(.debug)
        ResponseCompressionMiddleware(minimumResponseSizeToCompress: 256)
        FileMiddleware(logger: logger)
        SessionMiddleware(storage: fluentPersist)
    }

    // Web UI routes
    WebController(mustacheLibrary: library, fluent: fluent, sessionAuthenticator: sessionAuthenticator)
        .addRoutes(to: router)

    // API routes (unchanged — keep Basic auth)
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
    app.addServices(fluent, fluentPersist)
    return app
}
