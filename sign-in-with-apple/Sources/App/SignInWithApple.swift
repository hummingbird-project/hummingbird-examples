import AsyncHTTPClient
import Foundation
import Hummingbird
import JWTKit

struct SignInWithApple {
    struct AppleAuthResponse: Decodable {
        let code: String
        let state: String
        let idToken: String
        let user: String?

        private enum CodingKeys: String, CodingKey {
            case code
            case state
            case idToken = "id_token"
            case user
        }
    }
    struct AppleTokenRequestBody: Encodable {
        /// The application identifier for your app.
        let clientId: String

        /// A secret generated as a JSON Web Token that uses the secret key generated by the WWDR portal.
        let clientSecret: String

        /// The authorization code received from your application’s user agent. The code is single use only and valid for five minutes.
        let code: String

        /// The destination URI the code was originally sent to.
        let redirectUri: String

        /// The grant type that determines how the client interacts with the server.
        let grantType: String = "authorization_code"

        private enum CodingKeys: String, CodingKey {
            case clientId = "client_id"
            case clientSecret = "client_secret"
            case code
            case grantType = "grant_type"
            case redirectUri = "redirect_uri"
        }
    }

    struct AppleAuthToken: JWTPayload {
        let iss: IssuerClaim
        let iat: IssuedAtClaim
        let exp: ExpirationClaim
        let aud: AudienceClaim
        let sub: SubjectClaim

        init(clientId: String, teamId: String, expirationSeconds: Int = 86400 * 180) {
            sub = .init(value: clientId)
            iss = .init(value: teamId)
            let now = Date.now
            iat = .init(value: now)
            exp = .init(value: now + TimeInterval(expirationSeconds))
            aud = .init(value: ["https://appleid.apple.com"])
        }

        func verify(using algorithm: some JWTAlgorithm) throws {
            guard iss.value.count == 10 else {
                throw JWTError.claimVerificationFailure(
                    failedClaim: iss,
                    reason: "TeamId must be your 10-character Team ID from the developer portal"
                )
            }

            let lifetime = Int(exp.value.timeIntervalSinceReferenceDate - iat.value.timeIntervalSinceReferenceDate)
            guard 0...15_777_000 ~= lifetime else {
                throw JWTError.claimVerificationFailure(failedClaim: exp, reason: "Expiration must be between 0 and 15777000")
            }
        }
    }

    let siwaId: String
    let teamId: String
    let redirectURL: String
    let jwkIdentifier: JWKIdentifier
    let keys: JWTKeyCollection
    let httpClient: HTTPClient

    internal init(
        siwaId: String,
        teamId: String,
        jwkId: String,
        redirectURL: String,
        key: String,
        httpClient: HTTPClient
    ) async throws {
        self.siwaId = siwaId
        self.teamId = teamId
        self.redirectURL = redirectURL
        self.jwkIdentifier = JWKIdentifier(string: jwkId)
        let jwks = try await Self.getJWKS(httpClient: httpClient)
        self.keys = try await .init()
            .add(ecdsa: ES256PrivateKey(pem: key), kid: self.jwkIdentifier)
            .add(jwks: jwks)
        self.httpClient = httpClient
    }

    public func verify(
        _ message: String
    ) async throws -> AppleIdentityToken {
        let messageBytes = [UInt8](message.utf8)
        let token = try await keys.verify(messageBytes, as: AppleIdentityToken.self)
        try token.audience.verifyIntendedAudience(includes: siwaId)
        return token
    }

    /// The AppleIdentityToken is only short lived so we need to exchange it for an access token
    /// that lives for much longer
    func requestAccessToken(appleAuthResponse: AppleAuthResponse) async throws -> String {
        let secret = SignInWithApple.AppleAuthToken(clientId: self.siwaId, teamId: self.teamId)
        let secretJWTToken = try await self.keys.sign(secret, kid: self.jwkIdentifier)
        let appleTokenRequest = SignInWithApple.AppleTokenRequestBody(
            clientId: self.siwaId,
            clientSecret: secretJWTToken,
            code: appleAuthResponse.code,
            redirectUri: self.redirectURL
        )
        let requestBody = try URLEncodedFormEncoder().encode(appleTokenRequest)
        var request = HTTPClientRequest(url: "https://appleid.apple.com/auth/token")
        request.method = .POST
        request.headers = [
            "User-Agent": "Hummingbird/2.0",
            "Accept": "application/json",
            "Content-Type": "application/x-www-form-urlencoded",
        ]
        request.body = .bytes([UInt8](requestBody.utf8))
        let response = try await httpClient.execute(request, timeout: .seconds(60))
        let responseBody = String(buffer: try await response.body.collect(upTo: 1_000_000))
        return responseBody
    }

    /// Load JWKS from Apple
    static func getJWKS(httpClient: HTTPClient) async throws -> JWKS {
        let request = HTTPClientRequest(url: "https://appleid.apple.com/auth/keys")
        let response = try await httpClient.execute(request, timeout: .seconds(60))
        let jwks = try await response.body.collect(upTo: 1_000_000)
        return try JSONDecoder().decode(JWKS.self, from: jwks)
    }
}
