import FluentSQLiteDriver
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent
import NIOCore

protocol AppArguments {
    var migrate: Bool { get }
    var inMemoryDatabase: Bool { get }
}

/// build application
func buildApplication(_ arguments: AppArguments, configuration: ApplicationConfiguration) async throws -> some ApplicationProtocol {
    let fluent = Fluent(
        logger: Logger(label: "Sessions")
    )
    // add sqlite database
    fluent.databases.use(.sqlite(arguments.inMemoryDatabase ? .memory : .file("db.sqlite")), as: .sqlite)
    // set up persist driver before migrate
    let persist = await FluentPersistDriver(fluent: fluent)
    // add migrations
    await fluent.migrations.add(CreateUser())
    if arguments.migrate || arguments.inMemoryDatabase {
        try await fluent.migrate()
    }

    // Sessions
    let sessionStorage = SessionStorage(persist)

    let router = Router(context: BasicAuthRequestContext.self)

    // add logging middleware
    router.middlewares.add(LogRequestsMiddleware(.debug))

    // routes
    router.get("/") { _, _ in
        return "Hello"
    }

    let userController = UserController(fluent: fluent, sessionStorage: sessionStorage)
    userController.addRoutes(to: router.group("user"))

    var application = Application(
        router: router,
        server: .http1(),
        configuration: configuration
    )
    application.addServices(fluent, persist)
    return application
}
