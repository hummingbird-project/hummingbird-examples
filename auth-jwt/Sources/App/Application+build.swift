import AsyncHTTPClient
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
    let env = try await Environment().merging(with: .dotEnv())
    let logger = {
        var logger = Logger(label: "auth-jwt")
        logger.logLevel = .debug
        return logger
    }()
    let httpClient = HTTPClient.shared
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

    let jwtAuthenticator: JWTAuthenticator
    let jwtLocalSignerKid = JWKIdentifier("_hb_local_")
    if let jwksUrl = env.get("JWKS_URL") {
        do {
            let request = HTTPClientRequest(url: jwksUrl)
            let jwksResponse: HTTPClientResponse = try await httpClient.execute(request, timeout: .seconds(20))
            let jwksData = try await jwksResponse.body.collect(upTo: 1_000_000)
            jwtAuthenticator = try await JWTAuthenticator(jwksData: jwksData, fluent: fluent)
        } catch {
            logger.error("JWTAuthenticator initialization failed")
            throw error
        }
    } else {
        jwtAuthenticator = JWTAuthenticator(fluent: fluent)
    }
    await jwtAuthenticator.useSigner(hmac: "my-secret-key", digestAlgorithm: .sha256, kid: jwtLocalSignerKid)

    let router = Router(context: AppRequestContext.self)
    router.add(middleware: LogRequestsMiddleware(.debug))
    router.add(middleware:
        CORSMiddleware(
            allowOrigin: .originBased,
            allowHeaders: [.accept, .authorization, .contentType, .origin],
            allowMethods: [.get, .options]
        )
    )
    router.get("/") { _, _ in
        return "Hello"
    }
    UserController(
        jwtKeyCollection: jwtAuthenticator.jwtKeyCollection,
        kid: jwtLocalSignerKid,
        fluent: fluent
    ).addRoutes(to: router.group("user"))
    router.group("auth")
        .add(middleware: jwtAuthenticator)
        .get("/") { request, context in
            guard let user = context.identity else { throw HTTPError(.unauthorized) }
            return "Authenticated (Subject: \(user.name))"
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
