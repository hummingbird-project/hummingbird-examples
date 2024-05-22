import FluentSQLiteDriver
import Foundation
import Hummingbird
import HummingbirdFluent

public protocol AppArguments {
    var inMemoryDatabase: Bool { get }
    var migrate: Bool { get }
    var hostname: String { get }
    var port: Int { get }
}

func buildApplication(_ arguments: some AppArguments) async throws -> some ApplicationProtocol {
    let logger = Logger(label: "todos-fluent")
    let fluent = Fluent(logger: logger)
    // add sqlite database
    if arguments.inMemoryDatabase {
        fluent.databases.use(.sqlite(.memory), as: .sqlite)
    } else {
        fluent.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    }
    // add migrations
    await fluent.migrations.add(CreateTodo())

    let fluentPersist = await FluentPersistDriver(fluent: fluent)
    // migrate
    if arguments.migrate || arguments.inMemoryDatabase {
        try await fluent.migrate()
    }
    // router
    let router = Router()

    // add logging middleware
    router.middlewares.add(LogRequestsMiddleware(.info))
    // add file middleware to server css and js files
    router.middlewares.add(FileMiddleware(logger: logger))
    router.middlewares.add(CORSMiddleware(
        allowOrigin: .originBased,
        allowHeaders: [.contentType],
        allowMethods: [.get, .options, .post, .delete, .patch]
    ))
    // add health check route
    router.get("/health") { _, _ in
        return HTTPResponse.Status.ok
    }

    // Add api routes managing todos
    TodoController<BasicRequestContext>(fluent: fluent).addRoutes(to: router.group("api/todos"))

    var app = Application(
        router: router,
        configuration: .init(address: .hostname(arguments.hostname, port: arguments.port))
    )
    app.addServices(fluent, fluentPersist)
    return app
}
