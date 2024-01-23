import Hummingbird
import HummingbirdAuth
import SotoCognitoAuthenticationKit

extension CognitoAuthenticateResponse: HBAuthenticatable {}
extension CognitoAccessToken: HBAuthenticatable {}

/// Authenticator for Cognito username and password
struct CognitoBasicAuthenticator: HBAuthenticator {
    typealias Context = AuthCognitoRequestContext
    let cognitoAuthenticatable: CognitoAuthenticatable

    func authenticate(request: HBRequest, context: AuthCognitoRequestContext) async throws -> CognitoAuthenticateResponse? {
        guard let basic = request.headers.basic else { return nil }
        return try? await self.cognitoAuthenticatable.authenticate(
            username: basic.username,
            password: basic.password,
            context: HBCognitoContextData(request: request, context: context)
        )
    }
}

/// Authenticator for Cognito username and password
struct CognitoBasicSRPAuthenticator: HBAuthenticator {
    typealias Context = AuthCognitoRequestContext
    let cognitoAuthenticatable: CognitoAuthenticatable

    func authenticate(request: HBRequest, context: AuthCognitoRequestContext) async throws -> CognitoAuthenticateResponse? {
        guard let basic = request.headers.basic else { return nil }
        return try? await self.cognitoAuthenticatable.authenticateSRP(
            username: basic.username,
            password: basic.password,
            context: HBCognitoContextData(request: request, context: context)
        )
    }
}

/// Authenticator for Cognito access tokens
struct CognitoAccessAuthenticator: HBAuthenticator {
    typealias Context = AuthCognitoRequestContext
    let cognitoAuthenticatable: CognitoAuthenticatable

    func authenticate(request: HBRequest, context: AuthCognitoRequestContext) async throws -> CognitoAccessToken? {
        guard let bearer = request.headers.bearer else { return nil }
        return try? await self.cognitoAuthenticatable.authenticate(accessToken: bearer.token)
    }
}

/// Authenticator for Cognito id tokens. Can use this to extract information from Id Token into Payload struct. The list of standard list of claims found in an id token are
/// detailed in the [OpenID spec] (https://openid.net/specs/openid-connect-core-1_0.html#StandardClaims) . Your `Payload` type needs
/// to decode using these tags, plus the AWS specific "cognito:username" tag and any custom tags you have setup for the user pool.
struct CognitoIdAuthenticator<Payload: HBAuthenticatable & Codable>: HBAuthenticator {
    typealias Context = AuthCognitoRequestContext
    let cognitoAuthenticatable: CognitoAuthenticatable

    func authenticate(request: HBRequest, context: AuthCognitoRequestContext) async throws -> Payload? {
        guard let bearer = request.headers.bearer else { return nil }
        return try? await self.cognitoAuthenticatable.authenticate(idToken: bearer.token)
    }
}
