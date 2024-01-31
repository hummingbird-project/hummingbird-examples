import FluentSQLiteDriver
import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent
import HummingbirdMustache

public protocol AppArguments {
    var inMemoryDatabase: Bool { get }
    var migrate: Bool { get }
    var hostname: String { get }
    var port: Int { get }
}

@MainActor
func buildApplication(_ arguments: some AppArguments) async throws -> some HBApplicationProtocol {
    let logger = Logger(label: "todos-auth-fluent")
    let fluent = HBFluent(logger: logger)
    // add sqlite database
    if arguments.inMemoryDatabase {
        fluent.databases.use(.sqlite(.memory), as: .sqlite)
    } else {
        fluent.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    }
    // add migrations
    fluent.migrations.add(CreateTodo())
    fluent.migrations.add(CreateUser())

    let fluentPersist = await HBFluentPersistDriver(fluent: fluent)
    // migrate
    if arguments.migrate || arguments.inMemoryDatabase {
        try await fluent.migrate()
    }
    let sessionStorage = HBSessionStorage(fluentPersist)
    // router
    let router = HBRouter(context: TodosAuthRequestContext.self)

    // add logging middleware
    router.middlewares.add(HBLogRequestsMiddleware(.info))
    // add file middleware to server css and js files
    router.middlewares.add(HBFileMiddleware(logger: logger))
    router.middlewares.add(HBCORSMiddleware(
        allowOrigin: .originBased,
        allowHeaders: [.contentType],
        allowMethods: [.get, .options, .post, .delete, .patch]
    ))
    // add health check route
    router.get("/health") { _, _ in
        return HTTPResponse.Status.ok
    }

    // load mustache template library
    let library = try await HBMustacheLibrary(directory: "templates")
    assert(library.getTemplate(named: "head") != nil, "Set your working directory to the root folder of this example to get it to work")

    // Add routes serving HTML files
    WebController(mustacheLibrary: library, fluent: fluent, sessionStorage: sessionStorage).addRoutes(to: router)
    // Add api routes managing todos
    TodoController(fluent: fluent, sessionStorage: sessionStorage).addRoutes(to: router.group("api/todos"))
    // Add api routes managing users
    UserController(fluent: fluent, sessionStorage: sessionStorage).addRoutes(to: router.group("api/users"))

    var app = HBApplication(
        router: router,
        configuration: .init(address: .hostname(arguments.hostname, port: arguments.port))
    )
    app.addServices(fluent, fluentPersist)
    return app
}
