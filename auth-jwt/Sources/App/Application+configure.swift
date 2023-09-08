import AsyncHTTPClient
import Hummingbird
import HummingbirdAuth
import HummingbirdFoundation

extension HBApplication {
    public func configure() async throws {
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

        let jwtAuthenticator: JWTAuthenticator
        guard let jwksUrl = env.get("JWKS_URL") else { preconditionFailure("jwks config missing") }
        do {
            let request = HTTPClientRequest(url: jwksUrl)
            let jwksResponse: HTTPClientResponse = try await self.httpClient.execute(request, timeout: .seconds(20))
            let jwksData = try await jwksResponse.body.collect(upTo: 1_000_000)
            jwtAuthenticator = try JWTAuthenticator(jwksData: jwksData)
        } catch {
            self.logger.error("JWTAuthenticator initialization failed")
            throw error
        }

        router.get("/") { _ in
            return "Hello"
        }

        router.group("auth")
            .add(middleware: jwtAuthenticator)
            .get("/") { request in
                let jwtPayload = try request.authRequire(JWTPayloadData.self)
                return "Authenticated (Subject: \(jwtPayload.subject))"
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
