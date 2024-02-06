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

func buildApplication(_ args: AppArguments) async throws -> some HBApplicationProtocol {
    let env = try await HBEnvironment.shared.merging(with: .dotEnv())
    let logger = {
        var logger = Logger(label: "auth-jwt")
        logger.logLevel = .debug
        return logger
    }()
    let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
    let fluent = HBFluent(logger: logger)
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

    let jwtAuthenticator: JWTAuthenticator<HBAuthRequestContext>
    let jwtLocalSignerKid = JWKIdentifier("_hb_local_")
    if let jwksUrl = env.get("JWKS_URL") {
        do {
            let request = HTTPClientRequest(url: jwksUrl)
            let jwksResponse: HTTPClientResponse = try await httpClient.execute(request, timeout: .seconds(20))
            let jwksData = try await jwksResponse.body.collect(upTo: 1_000_000)
            jwtAuthenticator = try JWTAuthenticator(jwksData: jwksData, fluent: fluent)
        } catch {
            logger.error("JWTAuthenticator initialization failed")
            throw error
        }
    } else {
        jwtAuthenticator = JWTAuthenticator(fluent: fluent)
    }
    jwtAuthenticator.useSigner(.hs256(key: "my-secret-key"), kid: jwtLocalSignerKid)


    let router = HBRouter(context: HBAuthRequestContext.self)
    router.middlewares.add(HBLogRequestsMiddleware(.debug))
    router.middlewares.add(
        HBCORSMiddleware(
            allowOrigin: .originBased,
            allowHeaders: [.accept, .authorization, .contentType, .origin],
            allowMethods: [.get, .options]
        )
    )
    router.get("/") { _,_ in
        return "Hello"
    }
    UserController(jwtSigners: jwtAuthenticator.jwtSigners, kid: jwtLocalSignerKid, fluent: fluent).addRoutes(to: router.group("user"))
    router.group("auth")
        .add(middleware: jwtAuthenticator)
        .get("/") { request, context in
            let user = try context.auth.require(AuthenticatedUser.self)
            return "Authenticated (Subject: \(user.name))"
        }

    var app = HBApplication(
        router: router, 
        configuration: .init(
            address: .hostname(args.hostname, port: args.port),
            serverName: "auth-jwt"
        ),
        logger: logger
    )
    app.addServices(fluent, HTTPClientService(client: httpClient))

    return app
}

struct HTTPClientService: Service {
    let client: HTTPClient

    func run() async throws {
        await GracefulShutdownWaiter().wait()
        try await client.shutdown()
    }
}
/*extension HBApplication {
    func configure(arguments: AppArguments) async throws {
        let env = try HBEnvironment.shared.merging(with: .dotEnv())
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.httpClient = HTTPClient(eventLoopGroupProvider: .singleton)

        self.middleware.add(HBLogRequestsMiddleware(.debug))
        self.middleware.add(
            HBCORSMiddleware(
                allowOrigin: .originBased,
                allowHeaders: ["Accept", "Authorization", "Content-Type", "Origin"],
                allowMethods: [.GET, .OPTIONS]
            ))

        // add Fluent
        self.addFluent()
        // add sqlite database
        if arguments.inMemoryDatabase {
            self.fluent.databases.use(.sqlite(.memory), as: .sqlite)
        } else {
            self.fluent.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
        }
        // add migrations
        self.fluent.migrations.add(CreateUser())
        // migrate
        if arguments.migrate || arguments.inMemoryDatabase {
            try await self.fluent.migrate()
        }

        let jwtAuthenticator: JWTAuthenticator
        let jwtLocalSignerKid = JWKIdentifier("_hb_local_")
        if let jwksUrl = env.get("JWKS_URL") {
            do {
                let request = HTTPClientRequest(url: jwksUrl)
                let jwksResponse: HTTPClientResponse = try await self.httpClient.execute(request, timeout: .seconds(20))
                let jwksData = try await jwksResponse.body.collect(upTo: 1_000_000)
                jwtAuthenticator = try JWTAuthenticator(jwksData: jwksData)
            } catch {
                self.logger.error("JWTAuthenticator initialization failed")
                throw error
            }
        } else {
            jwtAuthenticator = JWTAuthenticator()
        }
        jwtAuthenticator.useSigner(.hs256(key: "my-secret-key"), kid: jwtLocalSignerKid)

        router.get("/") { _ in
            return "Hello"
        }
        UserController(jwtSigners: jwtAuthenticator.jwtSigners, kid: jwtLocalSignerKid).addRoutes(to: router.group("user"))
        router.group("auth")
            .add(middleware: jwtAuthenticator)
            .get("/") { request in
                let user = try request.authRequire(User.self)
                return "Authenticated (Subject: \(user.name))"
            }
    }
}*/

/*extension HBApplication {
    // Add HTTP client to HBApplication to control its lifecycle
    var httpClient: HTTPClient {
        get {
            self.extensions.get(\.httpClient, error: "Setup `HBApplication.httpClient` before using it.")
        }
        set {
            self.extensions.set(\.httpClient, value: newValue) { client in
                try? client.syncShutdown()
            }
        }
    }
}*/
