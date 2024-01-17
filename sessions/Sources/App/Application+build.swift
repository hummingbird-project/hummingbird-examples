import FluentSQLiteDriver
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent
import HummingbirdFoundation

protocol AppArguments {
    var migrate: Bool { get }
    var inMemoryDatabase: Bool { get }
}

/// Request context which default to using JSONDecoder/Encoder
struct SessionsContext: HBRequestContext, HBAuthRequestContextProtocol {
    init(allocator: ByteBufferAllocator, logger: Logger) {
        self.coreContext = .init(
            requestDecoder: JSONDecoder(),
            responseEncoder: JSONEncoder(),
            allocator: allocator,
            logger: logger
        )
        self.auth = .init()
    }

    var coreContext: HBCoreRequestContext
    /// Login cache
    public var auth: HBLoginCache
}

/// build application
func buildApplication(_ arguments: AppArguments, configuration: HBApplicationConfiguration) async throws -> some HBApplicationProtocol {
    let fluent = HBFluent(
        logger: Logger(label: "Sessions")
    )
    // add sqlite database
    fluent.databases.use(.sqlite(arguments.inMemoryDatabase ? .memory : .file("db.sqlite")), as: .sqlite)
    // set up persist driver before migrate
    let persist = await HBFluentPersistDriver(fluent: fluent)
    // add migrations
    await fluent.migrations.add(CreateUser())
    if arguments.migrate || arguments.inMemoryDatabase {
        try await fluent.migrate()
    }

    // Sessions
    let sessionStorage = HBSessionStorage(persist)

    let router = HBRouter(context: SessionsContext.self)

    // add logging middleware
    router.middlewares.add(HBLogRequestsMiddleware(.debug))

    // routes
    router.get("/") { _, _ in
        return "Hello"
    }

    let userController = UserController(fluent: fluent, sessionStorage: sessionStorage)
    userController.addRoutes(to: router.group("user"))

    var application = HBApplication(responder: router.buildResponder(), server: .http1())
    application.addServices(fluent, persist)
    return application
}
