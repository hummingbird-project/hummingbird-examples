import Hummingbird
import HummingbirdAuth
import HummingbirdFoundation

extension HBApplication {
  public func configure() throws {
    self.encoder = JSONEncoder()
    self.decoder = JSONDecoder()

    self.middleware.add(HBLogRequestsMiddleware(.debug))
    self.middleware.add(
      HBCORSMiddleware(
        allowOrigin: .all,
        allowHeaders: ["accept", "authorization", "content-type", "origin"],
        allowMethods: [.GET, .OPTIONS, .POST, .DELETE, .PATCH]
      ))

    middleware.add(HBFileMiddleware(application: self))
    router.get("/") { _ in
      return "Hello"
    }
  }
}
