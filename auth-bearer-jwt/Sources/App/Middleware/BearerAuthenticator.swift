import Foundation
import Hummingbird
import HummingbirdAuth
import JWTKit

struct TokenPayload: HBAuthenticatable {}

protocol DataProtocol {}

struct BearerAuthenticator: HBAsyncAuthenticator, DataProtocol {
  var jwksUrl: String

  func authenticate(request: HBRequest) async throws -> TokenPayload? {
    guard let jwtToken = request.authBearer else { throw HBHTTPError(.unauthorized) }
    print(jwtToken)
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
      contentsOf: URL(string: jwksUrl)!
    )

    let jwks = try JSONDecoder().decode(JWKS.self, from: jwksData)
    let signers = JWTSigners()
    try signers.use(jwks: jwks)
    let payload = try signers.verify(jwtToken.token, as: TestPayload.self)
    print(payload)

    // for testing only
    let token = TokenPayload()
    return token
  }
  // func authenticate(request: HBRequest) -> EventLoopFuture<User?> {
  //   guard let basic = request.auth. else { return request.success(nil) }
  //   // let authorization = request.headers["Authorization"].first
  //   // guard let user = request.auth.get(User.self) else { throw HBHTTPError(.unauthorized) }
  //   // return user
  // }
}
