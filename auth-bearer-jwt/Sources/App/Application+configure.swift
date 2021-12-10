import Hummingbird
import HummingbirdAuth
import HummingbirdFoundation

extension HBApplication {
  public func configure() throws {
    let env = HBEnvironment()
    
    self.encoder = JSONEncoder()
    self.decoder = JSONDecoder()

    self.middleware.add(HBLogRequestsMiddleware(.debug))
    self.middleware.add(
      HBCORSMiddleware(
        allowOrigin: .all,
        allowHeaders: ["accept", "authorization", "content-type", "origin"],
        allowMethods: [.GET, .OPTIONS]
      ))

    self.middleware.add(BearerAuthenticator(
      auth0Domain: env.get("AUTH0_DOMAIN")
    ))
    
    router.get("/") { _ in
      return "Hello"
    }
  }
}
