import Hummingbird
import HummingbirdAuth
import SotoCognitoAuthenticationKit

/// Authenticator for Cognito username and password
struct CognitoBasicAuthenticator: AuthenticatorMiddleware {
    typealias Context = AuthCognitoRequestContext
    let cognitoAuthenticatable: CognitoAuthenticatable

    func authenticate(
        request: Request,
        context: AuthCognitoRequestContext
    ) async throws -> Identity? {
        guard let basic = request.headers.basic else { return nil }
        guard let authenticateResponse = try? await self.cognitoAuthenticatable.authenticate(
            username: basic.username,
            password: basic.password,
            context: HBCognitoContextData(request: request, context: context)
        ) else {
            return nil
        }
        return .authenticateResponse(authenticateResponse)
    }
}

/// Authenticator for Cognito username and password
struct CognitoBasicSRPAuthenticator: AuthenticatorMiddleware {
    typealias Context = AuthCognitoRequestContext
    let cognitoAuthenticatable: CognitoAuthenticatable

    func authenticate(
        request: Request,
        context: AuthCognitoRequestContext
    ) async throws -> Identity? {
        guard let basic = request.headers.basic else { return nil }
        guard let authenticateResponse = try? await self.cognitoAuthenticatable.authenticateSRP(
            username: basic.username,
            password: basic.password,
            context: HBCognitoContextData(request: request, context: context)
        ) else {
            return nil
        }
        return .authenticateResponse(authenticateResponse)
    }
}

/// Authenticator for Cognito access tokens
struct CognitoAccessAuthenticator: AuthenticatorMiddleware {
    typealias Context = AuthCognitoRequestContext
    let cognitoAuthenticatable: CognitoAuthenticatable

    func authenticate(
        request: Request,
        context: AuthCognitoRequestContext
    ) async throws -> Identity? {
        guard let bearer = request.headers.bearer else { return nil }
        guard let token = try? await self.cognitoAuthenticatable.authenticate(
            accessToken: bearer.token
        ) else {
            return nil
        }
        return .accessToken(token)
    }
}

/// Authenticator for Cognito id tokens. Can use this to extract information from Id Token into Payload struct. The list of standard list of claims found in an id token are
/// detailed in the [OpenID spec] (https://openid.net/specs/openid-connect-core-1_0.html#StandardClaims) . Your `Payload` type needs
/// to decode using these tags, plus the AWS specific "cognito:username" tag and any custom tags you have setup for the user pool.
struct CognitoUserAuthenticator: AuthenticatorMiddleware {
    typealias Context = AuthCognitoRequestContext
    let cognitoAuthenticatable: CognitoAuthenticatable

    func authenticate(
        request: Request,
        context: AuthCognitoRequestContext
    ) async throws -> Identity? {
        guard let bearer = request.headers.bearer else { return nil }
        guard let user: User = try? await self.cognitoAuthenticatable.authenticate(
            idToken: bearer.token
        ) else {
            return nil
        }
        return .user(user)
    }
}
