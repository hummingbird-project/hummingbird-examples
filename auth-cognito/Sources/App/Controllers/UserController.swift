import ExtrasBase64
import Hummingbird
import HummingbirdAuth
import SotoCognitoAuthenticationKit
import SotoCognitoAuthenticationSRP

extension CognitoAccessToken: HBResponseEncodable {}
extension CognitoAuthenticateResponse: HBResponseEncodable {}
extension CognitoCreateUserResponse: HBResponseEncodable {}

final class UserController {
    /// Add UserController routews
    func addRoutes(to group: HBRouterGroup) {
        group.put(use: self.create)
            .patch(use: self.resend)
            .post("signup", use: self.signUp)
            .post("confirm", use: self.confirmSignUp)
            .post("refresh", use: self.refresh)
            .post("respond", use: self.respond)
            .post("respond/password", use: self.respondNewPassword)
            .post("respond/mfa", use: self.respondSoftwareMfa)
        group.group().add(middleware: CognitoBasicAuthenticator())
            .post("login", use: self.login)
        group.group().add(middleware: CognitoBasicSRPAuthenticator())
            .post("login/srp", use: self.loginSRP)
        group.group().add(middleware: CognitoAccessAuthenticator())
            .get("access", use: self.authenticateAccess)
            .patch("attributes", use: self.attributes)
            .get("mfa/setup", use: self.mfaGetSecretCode)
            .put("mfa/setup", use: self.mfaVerifyToken)
            .post("mfa/enable", use: self.enableMfa)
            .post("mfa/disable", use: self.disableMfa)
        group.group().add(middleware: CognitoIdAuthenticator<User>())
            .get("id", use: self.authenticateId)
    }

    /// create a user
    func create(_ request: HBRequest) -> EventLoopFuture<CognitoCreateUserResponse> {
        struct CreateUserRequest: Decodable {
            var username: String
            var attributes: [String: String]
        }
        guard let user = try? request.decode(as: CreateUserRequest.self) else { return request.failure(.badRequest) }
        return request.cognito.authenticatable.createUser(username: user.username, attributes: user.attributes, on: request.eventLoop)
    }

    /// resend create user email
    func resend(_ request: HBRequest) -> EventLoopFuture<CognitoCreateUserResponse> {
        struct ResendRequest: Decodable {
            var username: String
            var attributes: [String: String]
        }
        guard let user = try? request.decode(as: ResendRequest.self) else { return request.failure(.badRequest) }
        return request.cognito.authenticatable.createUser(username: user.username, attributes: user.attributes, messageAction: .resend, on: request.eventLoop)
    }

    /// response for signup
    struct SignUpResponse: HBResponseEncodable {
        var confirmed: Bool
        var userSub: String
    }

    /// sign up instead of create user
    func signUp(_ request: HBRequest) -> EventLoopFuture<SignUpResponse> {
        struct SignUpRequest: Decodable {
            var username: String
            var password: String
            var attributes: [String: String]
        }
        guard let user = try? request.decode(as: SignUpRequest.self) else { return request.failure(.badRequest) }
        return request.cognito.authenticatable.signUp(username: user.username, password: user.password, attributes: user.attributes, on: request.eventLoop)
            .map { .init(confirmed: $0.userConfirmed, userSub: $0.userSub) }
    }

    /// confirm sign up with confirmation code
    func confirmSignUp(_ request: HBRequest) -> EventLoopFuture<HTTPResponseStatus> {
        struct ConfirmSignUpRequest: Decodable {
            var username: String
            var code: String
        }
        guard let user = try? request.decode(as: ConfirmSignUpRequest.self) else { return request.failure(.badRequest) }
        return request.cognito.authenticatable.confirmSignUp(username: user.username, confirmationCode: user.code, on: request.eventLoop)
            .map { .ok }
    }

    /// Logs a user in, returning a token for accessing protected endpoints.
    func login(_ request: HBRequest) throws -> CognitoAuthenticateResponse {
        guard let authenticateResponse = request.authGet(CognitoAuthenticateResponse.self) else { throw HBHTTPError(.unauthorized) }
        return authenticateResponse
    }

    /// Logs a user in using Secure Remote Password, returning a token for accessing protected endpoints.
    func loginSRP(_ request: HBRequest) throws -> CognitoAuthenticateResponse {
        guard let authenticateResponse = request.authGet(CognitoAuthenticateResponse.self) else { throw HBHTTPError(.unauthorized) }
        return authenticateResponse
    }

    /// respond to authentication challenge
    func respond(_ request: HBRequest) -> EventLoopFuture<CognitoAuthenticateResponse> {
        struct ChallengeResponse: Codable {
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
            // context: request,
            on: request.eventLoop
        )
    }

    /// respond to new password authentication challenge
    func respondNewPassword(_ request: HBRequest) -> EventLoopFuture<CognitoAuthenticateResponse> {
        struct ChallengeResponse: Codable {
            let username: String
            let password: String
            let session: String
        }
        guard let response = try? request.decode(as: ChallengeResponse.self) else { return request.failure(.badRequest) }
        return request.cognito.authenticatable.respondToNewPasswordChallenge(
            username: response.username,
            password: response.password,
            session: response.session,
            // context: request,
            on: request.eventLoop
        )
    }

    /// authenticate access token
    func authenticateAccess(_ request: HBRequest) throws -> CognitoAccessToken {
        guard let token = request.authGet(CognitoAccessToken.self) else { throw HBHTTPError(.unauthorized) }
        return token
    }

    /// get user attributes
    func attributes(_ request: HBRequest) -> EventLoopFuture<String> {
        struct AttributesRequest: Codable {
            let attributes: [String: String]
        }
        guard let token = request.authGet(CognitoAccessToken.self) else { return request.failure(.unauthorized) }
        guard let attr = try? request.decode(as: AttributesRequest.self) else { return request.failure(.badRequest) }
        return request.cognito.authenticatable.updateUserAttributes(username: token.username, attributes: attr.attributes, on: request.eventLoop)
            .map { _ in "Success" }
    }

    /// authenticate id token
    func authenticateId(_ request: HBRequest) throws -> User {
        guard let token = request.authGet(User.self) else { throw HBHTTPError(.unauthorized) }
        return token
    }

    /// refresh tokens
    func refresh(_ request: HBRequest) -> EventLoopFuture<CognitoAuthenticateResponse> {
        struct RefreshRequest: Decodable {
            let username: String
        }
        guard let user = try? request.decode(as: RefreshRequest.self) else { return request.failure(.badRequest) }
        guard let refreshToken = request.authBearer?.token else { return request.failure(.badRequest) }
        return request.cognito.authenticatable.refresh(
            username: user.username,
            refreshToken: refreshToken,
            // context: request,
            on: request.eventLoop
        )
    }

    // MARK: MFA

    struct MfaGetTokenResponse: HBResponseEncodable {
        let authenticatorURL: String
        let session: String?
    }

    /// Get MFA secret code
    func mfaGetSecretCode(_ request: HBRequest) -> EventLoopFuture<MfaGetTokenResponse> {
        guard let token = request.authGet(CognitoAccessToken.self) else { return request.failure(.unauthorized) }
        guard let accessToken = request.authBearer else { return request.failure(.unauthorized) }
        return request.aws.cognitoIdentityProvider.associateSoftwareToken(.init(accessToken: accessToken.token))
            .flatMapThrowing { response in
                guard let secretCode = response.secretCode else {
                    throw HBHTTPError(.internalServerError)
                }
                let url = "otpauth://totp/\(token.username)?secret=\(secretCode)&issuer=hb-auth-cognito"
                return MfaGetTokenResponse(authenticatorURL: url, session: response.session)
            }
    }

    /// Verify MFA secret code
    func mfaVerifyToken(_ request: HBRequest) -> EventLoopFuture<HTTPResponseStatus> {
        struct VerifyRequest: Decodable {
            let deviceName: String?
            let session: String?
            let userCode: String
        }
        guard let accessToken = request.authBearer else { return request.failure(.unauthorized) }
        guard let verify = try? request.decode(as: VerifyRequest.self) else { return request.failure(.badRequest) }
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

    /// respond to software MFA authentication challenge
    func respondSoftwareMfa(_ request: HBRequest) -> EventLoopFuture<CognitoAuthenticateResponse> {
        struct MfaChallengeResponse: Codable {
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
            // context: context,
            on: request.eventLoop
        )
    }

    /// Enable MFA support
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

    /// Disable MFA support
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
