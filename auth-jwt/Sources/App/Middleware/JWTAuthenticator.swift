import Foundation
import Hummingbird
import HummingbirdAuth
import JWTKit
import NIOFoundationCompat

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

  init(jwksData: ByteBuffer) throws {
    self.jwks = try JSONDecoder().decode(JWKS.self, from: jwksData)
  }

  func authenticate(request: HBRequest) async throws -> JWTPayloadData? {
    guard let jwtToken = request.authBearer?.token else { throw HBHTTPError(.unauthorized) }

    let signers = JWTSigners()
    do {
      try signers.use(jwks: self.jwks)
      let payload = try signers.verify(jwtToken, as: JWTPayloadData.self)
      return payload
    } catch {
      request.logger.debug("couldn't verify token")
      throw HBHTTPError(.unauthorized)
    }
  }
}
