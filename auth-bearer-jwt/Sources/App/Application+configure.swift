import Hummingbird
import HummingbirdAuth
import HummingbirdFoundation

extension HBApplication {
  public func configure() throws {
    let env = HBEnvironment()
    self.encoder = JSONEncoder()
    self.decoder = JSONDecoder()

    let testing = env.get("jwks_url")
    print(testing)

    guard let jwksUrl = env.get("jwks_url") else { preconditionFailure("jwks config missing") }
    self.middleware.add(
      BearerAuthenticator(
        jwksUrl: jwksUrl
      ))

    router.get("/") { _ in
      return "Hello"
    }
  }
}
