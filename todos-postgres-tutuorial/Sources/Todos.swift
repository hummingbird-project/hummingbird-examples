import ArgumentParser
import Hummingbird
import Logging
@_spi(ConnectionPool) import PostgresNIO
import ServiceLifecycle

@main
struct Todos: AsyncParsableCommand, AppArguments {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 8080

    var inMemoryTesting: Bool { false }

    func run() async throws {
        // create application
        let app = try await buildApplication(self)
        // run application
        try await app.runService()
    }
}

/// Arguments extracted from commandline
protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var inMemoryTesting: Bool { get }
}

/// Build a HBApplication
func buildApplication(_ args: some AppArguments) async throws -> some HBApplicationProtocol {
    var logger = Logger(label: "Todos")
    logger.logLevel = .debug
    // create router
    let router = HBRouter(context: TodoRequestContext.self)
    // add logging middleware
    router.middlewares.add(HBLogRequestsMiddleware(.info))
    // add hello route
    router.get("/") { request, context in
        "Hello\n"
    }
    // add Todos API
    var postgresRepository: TodoPostgresRepository?
    if !args.inMemoryTesting {
        let client = PostgresClient(
            configuration: .init(host: "localhost", username: "todos", password: "todos", database: "hummingbird", tls: .disable),
            backgroundLogger: logger
        )
        let repository = TodoPostgresRepository(client: client, logger: logger)
        postgresRepository = repository
        TodoController(repository: repository).addRoutes(to: router.group("todos"))
    } else {
        TodoController(repository: TodoMemoryRepository()).addRoutes(to: router.group("todos"))
    }
    // create application
    var app = HBApplication(
        router: router,
        configuration: .init(address: .hostname(args.hostname, port: args.port)),
        logger: logger
    )
    // if we setup a postgres service then add as a service and run createTable before 
    // server starts
    if let postgresRepository {
        app.addServices(PostgresClientService(client: postgresRepository.client))
        app.runBeforeServerStart {
            try await postgresRepository.createTable()
        }
    }
    return app
}
