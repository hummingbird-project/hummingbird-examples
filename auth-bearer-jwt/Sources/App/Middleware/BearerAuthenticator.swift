import Foundation
import Hummingbird
import HummingbirdAuth
import JWTKit

struct AccessToken: HBAuthenticatable {
  var token = ""
  var name = ""
}

struct BearerAuthenticator: HBAsyncAuthenticator, DataProtocol {
  var token: String
  var auth0Domain: String

  func authenticate(request: HBRequest) async throws -> AccessToken? {
    guard let bearer = request.authBearer else { return nil }

    struct TestPayload: JWTPayload, Equatable {
      enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case name = "name"
        case isAdmin = "admin"
      }

      var subject: SubjectClaim
      var expiration: ExpirationClaim
      var name: String
      var isAdmin: Bool

      func verify(using signer: JWTSigner) throws {
        try self.expiration.verifyNotExpired()
      }
    }

    let jwksData = try Data(
      contentsOf: URL(string: "https://" + auth0Domain + ".auth0.com/.well-known/jwks.json")!
    )

    let jwks = try JSONDecoder().decode(JWKS.self, from: jwksData)
    let signers = JWTSigners()
    try signers.use(jwks: jwks)
    let payload = try signers.verify(bearer, as: TestPayload.self)
    print(payload)
    let token = AccessToken()
    return token
  }
  // func authenticate(request: HBRequest) -> EventLoopFuture<User?> {
  //   guard let basic = request.auth. else { return request.success(nil) }
  //   // let authorization = request.headers["Authorization"].first
  //   // guard let user = request.auth.get(User.self) else { throw HBHTTPError(.unauthorized) }
  //   // return user
  // }
}
