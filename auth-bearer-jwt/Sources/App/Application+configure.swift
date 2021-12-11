import Hummingbird
import HummingbirdAuth
import HummingbirdFoundation

extension HBApplication {
  public func configure() throws {
    let env = HBEnvironment.shared
    self.encoder = JSONEncoder()
    self.decoder = JSONDecoder()

    self.middleware.add(HBLogRequestsMiddleware(.debug))
    self.middleware.add(
      HBCORSMiddleware(
        allowOrigin: .originBased,
        allowHeaders: ["Accept", "Authorization", "Content-Type", "Origin"],
        allowMethods: [.GET, .OPTIONS]
      ))

    guard let jwksUrl = env.get("JWKS_URL") else { preconditionFailure("jwks config missing") }
    self.middleware.add(
      BearerAuthenticator(
        jwksUrl: jwksUrl
      ))

    router.get("/") { _ in
      return "Hello"
    }
  }
}
