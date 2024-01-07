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

    var testing: Bool { false }

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
    var testing: Bool { get }
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
    if !args.testing {
        let client = PostgresClient(
            configuration: .init(host: "localhost", username: "todos", password: "todos", database: "hummingbird", tls: .disable),
            backgroundLogger: logger
        )
        let repository = TodoPostgresRepository(client: client, logger: logger)
        postgresRepository = repository
        TodoController(repository: repository).addRoutes(to: router.group("todos"))
    } else {
        TodoController(repository: TodoMemoryRespository()).addRoutes(to: router.group("todos"))
    }
    let staticPostgresRepository = postgresRepository
    // create application
    var app = HBApplication(
        router: router,
        configuration: .init(address: .hostname(args.hostname, port: args.port)),
        onServerRunning: { _ in
            try? await staticPostgresRepository?.createTable()
        },
        logger: logger
    )
    if let postgresRepository {
        app.addServices(PostgresClientService(client: postgresRepository.client))
    }
    return app
}
