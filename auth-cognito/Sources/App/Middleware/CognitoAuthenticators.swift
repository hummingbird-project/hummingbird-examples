import Hummingbird
import HummingbirdAuth
import SotoCognitoAuthenticationKit

extension CognitoAuthenticateResponse: HBAuthenticatable {}
extension CognitoAccessToken: HBAuthenticatable {}

/// Authenticator for Cognito username and password
struct CognitoBasicAuthenticator: HBAuthenticator {
    func authenticate(request: HBRequest) -> EventLoopFuture<CognitoAuthenticateResponse?> {
        guard let basic = request.authBasic else { return request.success(nil) }
        return request.cognito.authenticatable.authenticate(username: basic.username, password: basic.password, context: request, on: request.eventLoop)
            .map { $0 }
            .recover { _ in nil }
    }
}

/// Authenticator for Cognito username and password
struct CognitoBasicSRPAuthenticator: HBAuthenticator {
    func authenticate(request: HBRequest) -> EventLoopFuture<CognitoAuthenticateResponse?> {
        guard let basic = request.authBasic else { return request.success(nil) }
        return request.cognito.authenticatable.authenticateSRP(username: basic.username, password: basic.password, context: request, on: request.eventLoop)
            .map { $0 }
            .recover { _ in nil }
    }
}

/// Authenticator for Cognito access tokens
struct CognitoAccessAuthenticator: HBAuthenticator {
    func authenticate(request: HBRequest) -> EventLoopFuture<CognitoAccessToken?> {
        guard let bearer = request.authBearer else { return request.success(nil) }
        return request.cognito.authenticatable.authenticate(accessToken: bearer.token, on: request.eventLoop)
            .map { $0 }
            .recover { _ in nil }
    }
}

/// Authenticator for Cognito id tokens. Can use this to extract information from Id Token into Payload struct. The list of standard list of claims found in an id token are
/// detailed in the [OpenID spec] (https://openid.net/specs/openid-connect-core-1_0.html#StandardClaims) . Your `Payload` type needs
/// to decode using these tags, plus the AWS specific "cognito:username" tag and any custom tags you have setup for the user pool.
struct CognitoIdAuthenticator<Payload: HBAuthenticatable & Codable>: HBAuthenticator {
    func authenticate(request: HBRequest) -> EventLoopFuture<Payload?> {
        guard let bearer = request.authBearer else { return request.success(nil) }
        return request.cognito.authenticatable.authenticate(idToken: bearer.token, on: request.eventLoop)
            .map { $0 }
            .recover { _ in nil }
    }
}
