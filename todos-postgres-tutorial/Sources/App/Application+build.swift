import Hummingbird
import Logging
import PostgresNIO

/// Application arguments protocol. We use a protocol so we can call
/// `buildApplication` inside Tests as well as in the App executable.
/// Any variables added here also have to be added to `App` in App.swift and
/// `TestArguments` in AppTest.swift
public protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var logLevel: Logger.Level? { get }
    var inMemoryTesting: Bool { get }
}

// Request context used by application
typealias AppRequestContext = BasicRequestContext

///  Build application
/// - Parameter arguments: application arguments
public func buildApplication(_ arguments: some AppArguments) async throws -> some ApplicationProtocol {
    let environment = Environment()
    let logger = {
        var logger = Logger(label: "todos-postgres-tutorial")
        logger.logLevel =
            arguments.logLevel ??
            environment.get("LOG_LEVEL").map { Logger.Level(rawValue: $0) ?? .info } ??
            .info
        return logger
    }()
    var postgresRepository: TodoPostgresRepository?
    let router: Router<AppRequestContext>
    if !arguments.inMemoryTesting {
        let client = PostgresClient(
            configuration: .init(host: "localhost", username: "todos", password: "todos", database: "hummingbird", tls: .disable),
            backgroundLogger: logger
        )
        let repository = TodoPostgresRepository(client: client, logger: logger)
        postgresRepository = repository
        router = buildRouter(repository)
    } else {
        router = buildRouter(TodoMemoryRepository())
    }
    var app = Application(
        router: router,
        configuration: .init(
            address: .hostname(arguments.hostname, port: arguments.port),
            serverName: "todos-postgres-tutorial"
        ),
        logger: logger
    )
    // if we setup a postgres service then add as a service and run createTable before
    // server starts
    if let postgresRepository {
        app.addServices(postgresRepository.client)
        app.beforeServerStarts {
            try await postgresRepository.createTable()
        }
    }
    return app
}

/// Build router
func buildRouter(_ repository: some TodoRepository) -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    // Add middleware
    router.addMiddleware {
        // logging middleware
        LogRequestsMiddleware(.info)
    }
    // Add health endpoint
    router.get("/health") { _, _ -> HTTPResponse.Status in
        return .ok
    }
    router.addRoutes(TodoController(repository: repository).endpoints, atPath: "/todos")
    return router
}
