import AsyncHTTPClient
import FluentKit
import FluentSQLiteDriver
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent
import HummingbirdFoundation

protocol AppArguments {
    var inMemoryDatabase: Bool { get }
    var migrate: Bool { get }
}

extension HBApplication {
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
        jwtAuthenticator.useSigner(.hs256(key: "my-secret-key"), kid: "_hb_local_")

        router.get("/") { _ in
            return "Hello"
        }
        UserController(jwtSigners: jwtAuthenticator.jwtSigners).addRoutes(to: router.group("users"))
        router.group("auth")
            .add(middleware: jwtAuthenticator)
            .get("/") { request in
                let user = try request.authRequire(User.self)
                return "Authenticated (Subject: \(user.name))"
            }
    }
}

extension HBApplication {
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
}
