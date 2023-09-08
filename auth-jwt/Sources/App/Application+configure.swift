import Hummingbird
import HummingbirdAuth
import HummingbirdFoundation

extension HBApplication {
    public func configure() throws {
        let env = try HBEnvironment.shared.merging(with: .dotEnv())
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()

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
            jwtAuthenticator = try JWTAuthenticator(jwksUrl: jwksUrl)
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
