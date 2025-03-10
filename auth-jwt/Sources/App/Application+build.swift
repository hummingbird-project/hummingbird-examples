import FluentKit
import FluentSQLiteDriver
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent
import JWTKit
import ServiceLifecycle

protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var inMemoryDatabase: Bool { get }
    var migrate: Bool { get }
}

typealias AppRequestContext = BasicAuthRequestContext<User>

func buildApplication(_ args: AppArguments) async throws -> some ApplicationProtocol {
    let logger = {
        var logger = Logger(label: "auth-jwt")
        logger.logLevel = .debug
        return logger
    }()
    let fluent = Fluent(logger: logger)
    // add sqlite database
    if args.inMemoryDatabase {
        fluent.databases.use(.sqlite(.memory), as: .sqlite)
    } else {
        fluent.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    }
    // add migrations
    await fluent.migrations.add(CreateUser())
    // migrate
    if args.migrate || args.inMemoryDatabase {
        try await fluent.migrate()
    }

    // Create JWT Key collection and add key for signing JWTs
    let jwtKeyCollection = JWTKeyCollection()
    await jwtKeyCollection.add(hmac: "my-secret-key", digestAlgorithm: .sha256, kid: JWKIdentifier("auth-jwt"))

    // Create router and add logging and CORS middleware
    let router = Router(context: AppRequestContext.self)
    router.add(middleware: LogRequestsMiddleware(.debug))
    router.add(
        middleware:
            CORSMiddleware(
                allowOrigin: .originBased,
                allowHeaders: [.accept, .authorization, .contentType, .origin],
                allowMethods: [.get, .options]
            )
    )

    // Add routes for creating and authenticating users using username/password
    UserController(
        jwtKeyCollection: jwtKeyCollection,
        kid: JWKIdentifier("auth-jwt"),
        fluent: fluent
    ).addRoutes(to: router.group("user"))

    // Add route that authenticates request using JWT included in Authentication token.
    router.group("auth")
        .add(middleware: JWTAuthenticator(jwtKeyCollection: jwtKeyCollection, fluent: fluent))
        .get("/") { request, context in
            guard let user = context.identity else { throw HTTPError(.unauthorized) }
            return "Authenticated (username: \(user.name))"
        }

    var app = Application(
        router: router,
        configuration: .init(
            address: .hostname(args.hostname, port: args.port),
            serverName: "auth-jwt"
        ),
        logger: logger
    )
    app.addServices(fluent)

    return app
}
