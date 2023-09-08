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
    let jwtSigners: JWTSigners

    init(jwksData: ByteBuffer) throws {
        let jwks = try JSONDecoder().decode(JWKS.self, from: jwksData)
        self.jwtSigners = JWTSigners()
        try self.jwtSigners.use(jwks: jwks)
    }

    init(_ signer: JWTSigner, kid: JWKIdentifier? = nil) throws {
        self.jwtSigners = JWTSigners()
        self.jwtSigners.use(signer, kid: kid)
    }

    func authenticate(request: HBRequest) async throws -> JWTPayloadData? {
        guard let jwtToken = request.authBearer?.token else { throw HBHTTPError(.unauthorized) }

        do {
            let payload = try self.jwtSigners.verify(jwtToken, as: JWTPayloadData.self)
            return payload
        } catch {
            request.logger.debug("couldn't verify token")
            throw HBHTTPError(.unauthorized)
        }
    }
}
