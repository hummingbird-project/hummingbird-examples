import Foundation
import Hummingbird
import HummingbirdAuth
import JWTKit

struct TokenPayload: HBAuthenticatable {
  var subject: String
}

protocol DataProtocol {}

struct JWTAuthenticator: HBAsyncAuthenticator, DataProtocol {
  var jwksUrl: String

  func authenticate(request: HBRequest) async throws -> TokenPayload? {
    guard let jwtToken = request.authBearer?.token else { throw HBHTTPError(.unauthorized) }

    struct TestPayload: JWTPayload, Equatable {
      enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
      }

      var subject: SubjectClaim
      var expiration: ExpirationClaim

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
    let payload = try signers.verify(jwtToken, as: TestPayload.self)

    return TokenPayload(
      subject: payload.subject.value
    )
  }
}
