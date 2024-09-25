import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdPostgres
import Logging
import Mustache
import PostgresMigrations
import PostgresNIO

/// Application arguments protocol. We use a protocol so we can call
/// `buildApplication` inside Tests as well as in the App executable.
/// Any variables added here also have to be added to `App` in App.swift and
/// `TestArguments` in AppTest.swift
public protocol AppArguments: Sendable {
    var hostname: String { get }
    var port: Int { get }
    var logLevel: Logger.Level? { get }
    var migrate: Bool { get }
}

///  Build application
/// - Parameter arguments: application arguments
public func buildApplication(_ arguments: some AppArguments) async throws -> some ApplicationProtocol {
    let environment = Environment()
    let logger = {
        var logger = Logger(label: "auth_otp")
        logger.logLevel =
            arguments.logLevel ??
            environment.get("LOG_LEVEL").flatMap { Logger.Level(rawValue: $0) } ??
            .info
        return logger
    }()
    let postgresClient = PostgresClient(
        configuration: .init(host: "localhost", username: "test_user", password: "test_password", database: "test_db", tls: .disable),
        backgroundLogger: logger
    )
    let migrations = DatabaseMigrations()
    await addDatabaseMigrations(to: migrations)
    let postgresPersist = await PostgresPersistDriver(client: postgresClient, migrations: migrations, logger: logger)
    let router = try await buildRouter(migrations: migrations, storage: postgresPersist, postgresClient: postgresClient)
    var app = Application(
        router: router,
        configuration: .init(
            address: .hostname(arguments.hostname, port: arguments.port),
            serverName: "auth_otp"
        ),
        services: [postgresClient, postgresPersist],
        logger: logger
    )
    app.beforeServerStarts {
        // try await migrations.revert(client: postgresClient, logger: logger, dryRun: !arguments.migrate)
        try await migrations.apply(client: postgresClient, logger: logger, dryRun: !arguments.migrate)
    }
    return app
}

/// Build router
func buildRouter(
    migrations: DatabaseMigrations,
    storage: some PersistDriver,
    postgresClient: PostgresClient
) async throws -> Router<AppRequestContext> {
    // Verify the working directory is correct
    assert(FileManager.default.fileExists(atPath: "public/images/hummingbird.png"), "Set your working directory to the root folder of this example to get it to work")
    // load mustache template library
    let mustacheLibrary = try await MustacheLibrary(directory: Bundle.module.resourcePath!)

    let router = Router(context: AppRequestContext.self)
    // Add middleware
    router.addMiddleware {
        // logging middleware
        LogRequestsMiddleware(.info)
        // file middleware
        FileMiddleware()
    }
    #if DEBUG
    router.add(middleware: ErrorLoggingMiddleware())
    #endif
    router.group("api")
        .addRoutes(
            UserController(
                users: UserPostgresRepository(client: postgresClient),
                storage: storage
            ).endpoints
        )
        .addRoutes(
            TOTPController(
                users: UserPostgresRepository(client: postgresClient),
                storage: storage
            ).endpoints
        )
    router.addRoutes(
        WebController(
            mustacheLibrary: mustacheLibrary,
            users: UserPostgresRepository(client: postgresClient),
            storage: storage
        ).endpoints
    )
    return router
}

/// Database migrations
func addDatabaseMigrations(to migrations: DatabaseMigrations) async {
    await migrations.add(CreateUserTable())
    await migrations.add(UserAddEmailIndex())
    await migrations.add(CreateTOTPTable())
}

struct ErrorLoggingMiddleware<Context: RequestContext>: RouterMiddleware {
    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        do {
            return try await next(request, context)
        } catch let error as HTTPResponseError {
            throw error
        } catch {
            context.logger.error("\(String(reflecting: error))")
            throw error
        }
    }
}
