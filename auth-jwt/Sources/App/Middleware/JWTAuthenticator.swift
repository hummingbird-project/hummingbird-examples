import Foundation
import Hummingbird
import HummingbirdAuth
import JWTKit

struct JWTPayloadData: JWTPayload, Equatable, HBAuthenticatable {
  enum CodingKeys: String, CodingKey {
    case subject = "sub"
    case expiration = "exp"
  }

  var subject: SubjectClaim
  var expiration: ExpirationClaim
  // Define additional JWT Attributes here

  func verify(using signer: JWTSigner) throws {
    try self.expiration.verifyNotExpired()
  }
}

struct JWTAuthenticator: HBAsyncAuthenticator {
  var jwks: JWKS

  init(jwksUrl: String) {
    do {
      let jwksKeys = URL(string: jwksUrl)!
      let jwksData = try Data(contentsOf: jwksKeys)
      jwks = try JSONDecoder().decode(JWKS.self, from: jwksData)
    } catch {
      print("middleware initialization failed")
      return
    }
  }

  func authenticate(request: HBRequest) async throws -> JWTPayloadData? {
    guard let jwtToken = request.authBearer?.token else { throw HBHTTPError(.unauthorized) }

    let signers = JWTSigners()
    do {
      try signers.use(jwks: jwks)
      let payload = try signers.verify(jwtToken, as: JWTPayloadData.self)
      return payload
    } catch {
      print("couldn't verify token")
      return nil
    }
  }
}
