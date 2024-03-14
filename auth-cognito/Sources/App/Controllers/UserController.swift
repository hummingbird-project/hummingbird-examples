import ExtrasBase64
import Hummingbird
import HummingbirdAuth
import HummingbirdRouter
import SotoCognitoAuthenticationKit
import SotoCognitoAuthenticationSRP

extension CognitoAccessToken: ResponseEncodable {}
extension CognitoAuthenticateResponse: ResponseEncodable {}
extension CognitoCreateUserResponse: ResponseEncodable {}

struct UserController {
    typealias Context = AuthCognitoRequestContext

    let cognitoAuthenticatable: CognitoAuthenticatable
    let cognitoIdentityProvider: CognitoIdentityProvider

    var endpoints: some RouterMiddleware<Context> {
        RouteGroup("user") {
            Put(handler: self.create)
            Patch(handler: self.resend)
            Post("signup", handler: self.signUp)
            Post("confirm", handler: self.confirmSignUp)
            Post("refresh", handler: self.refresh)
            Post("respond", handler: self.respond)
            Post("respond/password", handler: self.respondNewPassword)
            Post("respond/mfa", handler: self.respondSoftwareMfa)
            Post("login") {
                CognitoBasicAuthenticator(cognitoAuthenticatable: self.cognitoAuthenticatable)
                self.login
            }
            Post("login/srp") {
                CognitoBasicSRPAuthenticator(cognitoAuthenticatable: self.cognitoAuthenticatable)
                self.login
            }
            Get("id") {
                CognitoIdAuthenticator<User>(cognitoAuthenticatable: self.cognitoAuthenticatable)
                self.authenticateId
            }
            // all routes below require access authentication
            CognitoAccessAuthenticator(cognitoAuthenticatable: self.cognitoAuthenticatable)
            Get("access", handler: self.authenticateAccess)
            Patch("attributes", handler: self.attributes)
            Get("mfa/setup", handler: self.mfaGetSecretCode)
            Put("mfa/setup", handler: self.mfaVerifyToken)
            Post("mfa/enable", handler: self.enableMfa)
            Post("mfa/disable", handler: self.disableMfa)
        }
    }

    /// create a user
    @Sendable func create(_ request: Request, context: Context) async throws -> CognitoCreateUserResponse {
        struct CreateUserRequest: Decodable {
            var username: String
            var attributes: [String: String]
        }
        let user = try await request.decode(as: CreateUserRequest.self, context: context)
        return try await self.cognitoAuthenticatable.createUser(username: user.username, attributes: user.attributes)
    }

    /// resend create user email
    @Sendable func resend(_ request: Request, context: Context) async throws -> CognitoCreateUserResponse {
        struct ResendRequest: Decodable {
            var username: String
            var attributes: [String: String]
        }
        let user = try await request.decode(as: ResendRequest.self, context: context)
        return try await self.cognitoAuthenticatable.createUser(
            username: user.username,
            attributes: user.attributes,
            messageAction: .resend
        )
    }

    /// response for signup
    struct SignUpResponse: ResponseEncodable {
        var confirmed: Bool
        var userSub: String
    }

    /// sign up instead of create user
    @Sendable func signUp(_ request: Request, context: Context) async throws -> SignUpResponse {
        struct SignUpRequest: Decodable {
            var username: String
            var password: String
            var attributes: [String: String]
        }
        let user = try await request.decode(as: SignUpRequest.self, context: context)
        let response = try await cognitoAuthenticatable.signUp(username: user.username, password: user.password, attributes: user.attributes)
        return .init(confirmed: response.userConfirmed, userSub: response.userSub)
    }

    /// confirm sign up with confirmation code
    @Sendable func confirmSignUp(_ request: Request, context: Context) async throws -> HTTPResponse.Status {
        struct ConfirmSignUpRequest: Decodable {
            var username: String
            var code: String
        }
        let user = try await request.decode(as: ConfirmSignUpRequest.self, context: context)
        try await self.cognitoAuthenticatable.confirmSignUp(username: user.username, confirmationCode: user.code)
        return .ok
    }

    /// Logs a user in, returning a token for accessing protected endpoints.
    @Sendable func login(_ request: Request, context: Context) throws -> CognitoAuthenticateResponse {
        let authenticateResponse = try context.auth.require(CognitoAuthenticateResponse.self)
        return authenticateResponse
    }

    /// Logs a user in using Secure Remote Password, returning a token for accessing protected endpoints.
    @Sendable func loginSRP(_ request: Request, context: Context) throws -> CognitoAuthenticateResponse {
        let authenticateResponse = try context.auth.require(CognitoAuthenticateResponse.self)
        return authenticateResponse
    }

    /// respond to authentication challenge
    @Sendable func respond(_ request: Request, context: Context) async throws -> CognitoAuthenticateResponse {
        struct ChallengeResponse: Codable {
            let username: String
            let name: CognitoChallengeName
            let responses: [String: String]
            let session: String
        }
        let response = try await request.decode(as: ChallengeResponse.self, context: context)
        return try await self.cognitoAuthenticatable.respondToChallenge(
            username: response.username,
            name: response.name,
            responses: response.responses,
            session: response.session
        )
    }

    /// respond to new password authentication challenge
    @Sendable func respondNewPassword(_ request: Request, context: Context) async throws -> CognitoAuthenticateResponse {
        struct ChallengeResponse: Codable {
            let username: String
            let password: String
            let session: String
        }
        let response = try await request.decode(as: ChallengeResponse.self, context: context)
        return try await self.cognitoAuthenticatable.respondToNewPasswordChallenge(
            username: response.username,
            password: response.password,
            session: response.session
        )
    }

    /// authenticate access token
    @Sendable func authenticateAccess(_ request: Request, context: Context) throws -> CognitoAccessToken {
        let token = try context.auth.require(CognitoAccessToken.self)
        return token
    }

    /// get user attributes
    @Sendable func attributes(_ request: Request, context: Context) async throws -> String {
        struct AttributesRequest: Codable {
            let attributes: [String: String]
        }
        let token = try context.auth.require(CognitoAccessToken.self)
        let attr = try await request.decode(as: AttributesRequest.self, context: context)
        try await self.cognitoAuthenticatable.updateUserAttributes(username: token.username, attributes: attr.attributes)
        return "Success"
    }

    /// authenticate id token
    @Sendable func authenticateId(_ request: Request, context: Context) throws -> User {
        let token = try context.auth.require(User.self)
        return token
    }

    /// refresh tokens
    @Sendable func refresh(_ request: Request, context: Context) async throws -> CognitoAuthenticateResponse {
        struct RefreshRequest: Decodable {
            let username: String
        }
        let user = try await request.decode(as: RefreshRequest.self, context: context)
        guard let refreshToken = request.headers.bearer?.token else { throw HTTPError(.badRequest) }
        return try await self.cognitoAuthenticatable.refresh(
            username: user.username,
            refreshToken: refreshToken
        )
    }

    // MARK: MFA

    struct MfaGetTokenResponse: ResponseEncodable {
        let authenticatorURL: String
        let session: String?
    }

    /// Get MFA secret code
    @Sendable func mfaGetSecretCode(_ request: Request, context: Context) async throws -> MfaGetTokenResponse {
        let token = try context.auth.require(CognitoAccessToken.self)
        guard let accessToken = request.headers.bearer else { throw HTTPError(.unauthorized) }
        let response = try await cognitoIdentityProvider.associateSoftwareToken(.init(accessToken: accessToken.token))
        guard let secretCode = response.secretCode else {
            throw HTTPError(.internalServerError)
        }
        let url = "otpauth://totp/\(token.username)?secret=\(secretCode)&issuer=hb-auth-cognito"
        return MfaGetTokenResponse(authenticatorURL: url, session: response.session)
    }

    /// Verify MFA secret code
    @Sendable func mfaVerifyToken(_ request: Request, context: Context) async throws -> HTTPResponse.Status {
        struct VerifyRequest: Decodable {
            let deviceName: String?
            let session: String?
            let userCode: String
        }
        guard let accessToken = request.headers.bearer else { throw HTTPError(.unauthorized) }
        let verify = try await request.decode(as: VerifyRequest.self, context: context)
        let verifySoftwareTokenRequest = CognitoIdentityProvider.VerifySoftwareTokenRequest(
            accessToken: accessToken.token,
            friendlyDeviceName: verify.deviceName,
            session: verify.session,
            userCode: verify.userCode
        )
        let response = try await cognitoIdentityProvider.verifySoftwareToken(verifySoftwareTokenRequest)
        switch response.status {
        case .success:
            return .ok
        default:
            return .unauthorized
        }
    }

    /// respond to software MFA authentication challenge
    @Sendable func respondSoftwareMfa(_ request: Request, context: Context) async throws -> CognitoAuthenticateResponse {
        struct MfaChallengeResponse: Codable {
            let username: String
            let code: String
            let session: String
        }
        let response = try await request.decode(as: MfaChallengeResponse.self, context: context)
        return try await self.cognitoAuthenticatable.respondToChallenge(
            username: response.username,
            name: .softwareTokenMfa,
            responses: ["SOFTWARE_TOKEN_MFA_CODE": response.code],
            session: response.session
        )
    }

    /// Enable MFA support
    @Sendable func enableMfa(_ request: Request, context: Context) async throws -> HTTPResponse.Status {
        let token = try context.auth.require(CognitoAccessToken.self)
        let setUserMfaRequest = CognitoIdentityProvider.AdminSetUserMFAPreferenceRequest(
            softwareTokenMfaSettings: .init(enabled: true, preferredMfa: true),
            username: token.username,
            userPoolId: self.cognitoAuthenticatable.configuration.userPoolId
        )
        _ = try await self.cognitoIdentityProvider.adminSetUserMFAPreference(setUserMfaRequest)
        return .ok
    }

    /// Disable MFA support
    @Sendable func disableMfa(_ request: Request, context: Context) async throws -> HTTPResponse.Status {
        struct Password: Decodable {
            let password: String
        }

        let token = try context.auth.require(CognitoAccessToken.self)
        let password = try await request.decode(as: Password.self, context: context)

        _ = try await self.cognitoAuthenticatable.authenticate(username: token.username, password: password.password)
        let setUserMfaRequest = CognitoIdentityProvider.AdminSetUserMFAPreferenceRequest(
            softwareTokenMfaSettings: .init(enabled: false, preferredMfa: false),
            username: token.username,
            userPoolId: self.cognitoAuthenticatable.configuration.userPoolId
        )
        _ = try await self.cognitoIdentityProvider.adminSetUserMFAPreference(setUserMfaRequest)
        return .ok
    }
}
