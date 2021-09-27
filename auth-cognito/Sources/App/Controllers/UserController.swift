import Hummingbird
import HummingbirdAuth
import SotoCognitoAuthenticationKit
import SotoCognitoAuthenticationSRP

extension CognitoAccessToken: HBResponseEncodable {}
extension CognitoAuthenticateResponse: HBResponseEncodable {}
extension CognitoCreateUserResponse: HBResponseEncodable {}

final class UserController {
    func addRoutes(to group: HBRouterGroup) {
        group.put(use: create)
            .post("respond", use: respond)
            .post("respond/password", use: respondNewPassword)
            .post("respond/mfa", use: respondSoftwareMfa)
        group.group().add(middleware: CognitoBasicAuthenticator())
            .post("login", use: login)
        group.group().add(middleware: CognitoBasicSRPAuthenticator())
            .post("login/srp", use: loginSRP)
        group.group().add(middleware: CognitoAccessAuthenticator())
            .get("access", use: authenticateAccess)
            .patch("attributes", use: attributes)
            .get("mfa/setup", use: mfaGetSecretCode)
            .put("mfa/setup", use: mfaVerifyToken)
            .post("mfa/enable", use: enableMfa)
            .post("mfa/disable", use: disableMfa)
        group.group().add(middleware: CognitoIdAuthenticator<User>())
            .get("id", use: authenticateId)
    }

    /// create
    func create(_ request: HBRequest) -> EventLoopFuture<CognitoCreateUserResponse> {
        guard let user = try? request.decode(as: SignUp.self) else { return request.failure(.badRequest) }
        var attributes: [String: String] = [:]
        attributes["email"] = user.email
        return request.cognito.authenticatable.createUser(username: user.username, attributes: attributes, on: request.eventLoop)
    }

    /// Logs a user in, returning a token for accessing protected endpoints.
    func login(_ request: HBRequest) throws -> CognitoAuthenticateResponse {
        guard let authenticateResponse = request.authGet(CognitoAuthenticateResponse.self) else { throw HBHTTPError(.unauthorized) }
        return authenticateResponse
    }

    /// Logs a user in, returning a token for accessing protected endpoints.
    func loginSRP(_ request: HBRequest) throws -> CognitoAuthenticateResponse {
        guard let authenticateResponse = request.authGet(CognitoAuthenticateResponse.self) else { throw HBHTTPError(.unauthorized) }
        return authenticateResponse
    }

    /// respond to authenticate challenge
    func respond(_ request: HBRequest) -> EventLoopFuture<CognitoAuthenticateResponse> {
        struct ChallengeResponse : Codable {
            let username: String
            let name: CognitoChallengeName
            let responses: [String: String]
            let session: String
        }
        guard let response = try? request.decode(as: ChallengeResponse.self) else { return request.failure(.badRequest) }
        return request.cognito.authenticatable.respondToChallenge(
            username: response.username,
            name: response.name,
            responses: response.responses,
            session: response.session,
            //context: request,
            on: request.eventLoop
        )
    }

    /// respond to authenticate challenge
    func respondNewPassword(_ request: HBRequest) -> EventLoopFuture<CognitoAuthenticateResponse> {
        struct ChallengeResponse : Codable {
            let username: String
            let password: String
            let session: String
        }
        guard let response = try? request.decode(as: ChallengeResponse.self) else { return request.failure(.badRequest) }
        return request.cognito.authenticatable.respondToNewPasswordChallenge(
            username: response.username,
            password: response.password,
            session: response.session,
            //context: request,
            on: request.eventLoop
        )
    }

    /// authenticate
    func authenticateAccess(_ request: HBRequest) throws -> CognitoAccessToken {
        guard let token = request.authGet(CognitoAccessToken.self) else { throw HBHTTPError(.unauthorized) }
        return token
    }

    /// attributes
    func attributes(_ request: HBRequest) -> EventLoopFuture<String> {
        struct AttributesRequest: Codable {
            let attributes: [String: String]
        }
        guard let token = request.authGet(CognitoAccessToken.self) else { return request.failure(.unauthorized) }
        guard let attr = try? request.decode(as: AttributesRequest.self) else { return request.failure(.badRequest) }
        return request.cognito.authenticatable.updateUserAttributes(username: token.username, attributes: attr.attributes, on: request.eventLoop)
            .map { _ in "Success"}
    }

    /// user
    func authenticateId(_ request: HBRequest) throws -> User {
        guard let token = request.authGet(User.self) else { throw HBHTTPError(.unauthorized) }
        return token
    }

    /// refresh token
    func refresh(_ request: HBRequest) -> EventLoopFuture<CognitoAuthenticateResponse> {
        struct RefreshRequest: Decodable {
            let username: String
        }
        guard let user = try? request.decode(as: RefreshRequest.self) else { return request.failure(.badRequest) }
        guard let refreshToken = request.authBearer?.token else { return request.failure(.badRequest) }
        return request.cognito.authenticatable.refresh(
            username: user.username,
            refreshToken: refreshToken,
            //context: request,
            on: request.eventLoop
        )
    }

    //MARK: MFA

    func mfaGetSecretCode(_ request: HBRequest) -> EventLoopFuture<MfaGetTokenResponse> {
        guard let accessToken = request.authBearer else { return request.failure(.unauthorized) }
        return request.aws.cognitoIdentityProvider.associateSoftwareToken(.init(accessToken: accessToken.token))
            .flatMapThrowing { response in
                guard let secretCode = response.secretCode else {
                    throw HBHTTPError(.internalServerError)
                }
                return MfaGetTokenResponse(secretCode: secretCode, session: response.session)
            }
    }

    func mfaVerifyToken(_ request: HBRequest) -> EventLoopFuture<HTTPResponseStatus> {
        struct VerifyRequest: Decodable {
            let deviceName: String?
            let session: String?
            let userCode: String
        }
        guard let accessToken = request.authBearer else { return request.failure(.unauthorized) }
        guard let verify = try? request.decode(as: VerifyRequest.self) else { return request.failure(.badRequest)}
        let verifySoftwareTokenRequest = CognitoIdentityProvider.VerifySoftwareTokenRequest(
            accessToken: accessToken.token,
            friendlyDeviceName: verify.deviceName,
            session: verify.session,
            userCode: verify.userCode
        )
        return request.aws.cognitoIdentityProvider.verifySoftwareToken(verifySoftwareTokenRequest)
            .map { response in
                switch response.status {
                case .success:
                    return .ok
                default:
                    return .unauthorized
                }
            }
    }

    /// respond to authenticate challenge
    func respondSoftwareMfa(_ request: HBRequest) -> EventLoopFuture<CognitoAuthenticateResponse> {
        struct MfaChallengeResponse : Codable {
            let username: String
            let code: String
            let session: String
        }
        guard let response = try? request.decode(as: MfaChallengeResponse.self) else { return request.failure(.badRequest) }
        return request.cognito.authenticatable.respondToChallenge(
            username: response.username,
            name: .softwareTokenMfa,
            responses: ["SOFTWARE_TOKEN_MFA_CODE": response.code],
            session: response.session,
            //context: context,
            on: request.eventLoop
        )
    }

    /// respond to authenticate challenge
    func enableMfa(_ request: HBRequest) -> EventLoopFuture<HTTPResponseStatus> {
        guard let token = request.authGet(CognitoAccessToken.self) else { return request.failure(.unauthorized) }
        let setUserMfaRequest = CognitoIdentityProvider.AdminSetUserMFAPreferenceRequest(
            softwareTokenMfaSettings: .init(enabled: true, preferredMfa: true),
            username: token.username,
            userPoolId: request.cognito.authenticatable.configuration.userPoolId
        )
        return request.aws.cognitoIdentityProvider.adminSetUserMFAPreference(setUserMfaRequest)
            .map { _ in .ok }
    }

    /// respond to authenticate challenge
    func disableMfa(_ request: HBRequest) -> EventLoopFuture<HTTPResponseStatus> {
        struct Password: Decodable {
            let password: String
        }

        guard let token = request.authGet(CognitoAccessToken.self) else { return request.failure(.unauthorized) }
        guard let password = try? request.decode(as: Password.self) else { return request.failure(.badRequest) }

        return request.cognito.authenticatable.authenticate(username: token.username, password: password.password, on: request.eventLoop)
            .flatMap { _ in
                let setUserMfaRequest = CognitoIdentityProvider.AdminSetUserMFAPreferenceRequest(
                    softwareTokenMfaSettings: .init(enabled: false, preferredMfa: false),
                    username: token.username,
                    userPoolId: request.cognito.authenticatable.configuration.userPoolId
                )
                return request.aws.cognitoIdentityProvider.adminSetUserMFAPreference(setUserMfaRequest)
                    .map { _ in .ok }
            }

    }

}
