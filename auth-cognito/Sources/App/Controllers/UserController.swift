import ExtrasBase64
import Hummingbird
import HummingbirdAuth
import HummingbirdRouter
import SotoCognitoAuthenticationKit
import SotoCognitoAuthenticationSRP

extension CognitoAccessToken: @retroactive ResponseEncodable {}
extension CognitoAuthenticateResponse: @retroactive ResponseEncodable {}
extension CognitoCreateUserResponse: @retroactive ResponseEncodable {}

struct UserController: RouterController {
    typealias Context = AuthCognitoRequestContext

    let cognitoAuthenticatable: CognitoAuthenticatable
    let cognitoIdentityProvider: CognitoIdentityProvider

    var body: some RouterMiddleware<Context> {
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
                CognitoBasicAuthenticator(
                    cognitoAuthenticatable: self.cognitoAuthenticatable
                )
                self.login
            }
            Post("login/srp") {
                CognitoBasicSRPAuthenticator(
                    cognitoAuthenticatable: self.cognitoAuthenticatable
                )
                self.login
            }
            Get("id") {
                CognitoUserAuthenticator(
                    cognitoAuthenticatable: self.cognitoAuthenticatable
                )
                self.authenticateId
            }
            // all routes below require access authentication
            CognitoAccessAuthenticator(
                cognitoAuthenticatable: self.cognitoAuthenticatable
            )
            Get("access", handler: self.authenticateAccess)
            Patch("attributes", handler: self.attributes)
            Get("mfa/setup", handler: self.mfaGetSecretCode)
            Put("mfa/setup", handler: self.mfaVerifyToken)
            Post("mfa/enable", handler: self.enableMfa)
            Post("mfa/disable", handler: self.disableMfa)
        }
    }

    /// create a user
    func create(
        _ request: Request,
        context: Context
    ) async throws -> CognitoCreateUserResponse {
        struct CreateUserRequest: Decodable {
            var username: String
            var attributes: [String: String]
        }
        let user = try await request.decode(
            as: CreateUserRequest.self,
            context: context
        )
        return try await self.cognitoAuthenticatable.createUser(
            username: user.username,
            attributes: user.attributes
        )
    }

    /// resend create user email
    func resend(
        _ request: Request,
        context: Context
    ) async throws -> CognitoCreateUserResponse {
        struct ResendRequest: Decodable {
            var username: String
            var attributes: [String: String]
        }
        let user = try await request.decode(
            as: ResendRequest.self,
            context: context
        )
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
    func signUp(
        _ request: Request,
        context: Context
    ) async throws -> SignUpResponse {
        struct SignUpRequest: Decodable {
            var username: String
            var password: String
            var attributes: [String: String]
        }
        let user = try await request.decode(
            as: SignUpRequest.self,
            context: context
        )
        let response = try await cognitoAuthenticatable.signUp(
            username: user.username,
            password: user.password,
            attributes: user.attributes
        )
        return .init(confirmed: response.userConfirmed, userSub: response.userSub)
    }

    /// confirm sign up with confirmation code
    func confirmSignUp(
        _ request: Request,
        context: Context
    ) async throws -> HTTPResponse.Status {
        struct ConfirmSignUpRequest: Decodable {
            var username: String
            var code: String
        }
        let user = try await request.decode(
            as: ConfirmSignUpRequest.self,
            context: context
        )
        try await self.cognitoAuthenticatable.confirmSignUp(
            username: user.username,
            confirmationCode: user.code
        )
        return .ok
    }

    /// Logs a user in, returning a token for accessing protected endpoints.
    func login(
        _ request: Request,
        context: Context
    ) throws -> CognitoAuthenticateResponse {
        guard case .authenticateResponse(let response) = context.identity else {
            throw HTTPError(.unauthorized)
        }
        return response
    }

    /// Logs a user in using Secure Remote Password, returning a token for accessing protected endpoints.
    func loginSRP(
        _ request: Request,
        context: Context
    ) throws -> CognitoAuthenticateResponse {
        guard case .authenticateResponse(let response) = context.identity else {
            throw HTTPError(.unauthorized)
        }
        return response
    }

    /// respond to authentication challenge
    func respond(
        _ request: Request,
        context: Context
    ) async throws -> CognitoAuthenticateResponse {
        struct ChallengeResponse: Codable {
            let username: String
            let name: CognitoChallengeName
            let responses: [String: String]
            let session: String
        }
        let response = try await request.decode(
            as: ChallengeResponse.self,
            context: context
        )
        return try await self.cognitoAuthenticatable.respondToChallenge(
            username: response.username,
            name: response.name,
            responses: response.responses,
            session: response.session
        )
    }

    /// respond to new password authentication challenge
    func respondNewPassword(
        _ request: Request,
        context: Context
    ) async throws -> CognitoAuthenticateResponse {
        struct ChallengeResponse: Codable {
            let username: String
            let password: String
            let session: String
        }
        let response = try await request.decode(
            as: ChallengeResponse.self,
            context: context
        )
        return try await self.cognitoAuthenticatable.respondToNewPasswordChallenge(
            username: response.username,
            password: response.password,
            session: response.session
        )
    }

    /// authenticate access token
    func authenticateAccess(
        _ request: Request,
        context: Context
    ) throws -> CognitoAccessToken {
        guard case .accessToken(let token) = context.identity else {
            throw HTTPError(.unauthorized)
        }
        return token
    }

    /// get user attributes
    func attributes(
        _ request: Request,
        context: Context
    ) async throws -> String {
        struct AttributesRequest: Codable {
            let attributes: [String: String]
        }
        guard case .accessToken(let token) = context.identity else {
            throw HTTPError(.unauthorized)
        }
        let attr = try await request.decode(as: AttributesRequest.self, context: context)
        try await self.cognitoAuthenticatable.updateUserAttributes(
            username: token.username,
            attributes: attr.attributes
        )
        return "Success"
    }

    /// authenticate id token
    func authenticateId(
        _ request: Request,
        context: Context
    ) throws -> User {
        guard case .user(let user) = context.identity else {
            throw HTTPError(.unauthorized)
        }
        return user
    }

    /// refresh tokens
    func refresh(
        _ request: Request,
        context: Context
    ) async throws -> CognitoAuthenticateResponse {
        struct RefreshRequest: Decodable {
            let username: String
        }
        let user = try await request.decode(
            as: RefreshRequest.self,
            context: context
        )
        guard let refreshToken = request.headers.bearer?.token else {
            throw HTTPError(.badRequest)
        }
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
    func mfaGetSecretCode(
        _ request: Request,
        context: Context
    ) async throws -> MfaGetTokenResponse {
        guard case .accessToken(let token) = context.identity else {
            throw HTTPError(.unauthorized)
        }
        guard let accessToken = request.headers.bearer else {
            throw HTTPError(.unauthorized)
        }
        let response = try await cognitoIdentityProvider.associateSoftwareToken(
            .init(accessToken: accessToken.token)
        )
        guard let secretCode = response.secretCode else {
            throw HTTPError(.internalServerError)
        }
        let url = "otpauth://totp/\(token.username)?secret=\(secretCode)&issuer=hb-auth-cognito"
        return MfaGetTokenResponse(
            authenticatorURL: url,
            session: response.session
        )
    }

    /// Verify MFA secret code
    func mfaVerifyToken(
        _ request: Request,
        context: Context
    ) async throws -> HTTPResponse.Status {
        struct VerifyRequest: Decodable {
            let deviceName: String?
            let session: String?
            let userCode: String
        }
        guard let accessToken = request.headers.bearer else {
            throw HTTPError(.unauthorized)
        }
        let verify = try await request.decode(
            as: VerifyRequest.self,
            context: context
        )
        let verifySoftwareTokenRequest = CognitoIdentityProvider.VerifySoftwareTokenRequest(
            accessToken: accessToken.token,
            friendlyDeviceName: verify.deviceName,
            session: verify.session,
            userCode: verify.userCode
        )
        let response = try await cognitoIdentityProvider.verifySoftwareToken(
            verifySoftwareTokenRequest
        )
        switch response.status {
        case .success:
            return .ok
        default:
            return .unauthorized
        }
    }

    /// respond to software MFA authentication challenge
    func respondSoftwareMfa(
        _ request: Request,
        context: Context
    ) async throws -> CognitoAuthenticateResponse {
        struct MfaChallengeResponse: Codable {
            let username: String
            let code: String
            let session: String
        }
        let response = try await request.decode(
            as: MfaChallengeResponse.self,
            context: context
        )
        return try await self.cognitoAuthenticatable.respondToChallenge(
            username: response.username,
            name: .softwareTokenMfa,
            responses: ["SOFTWARE_TOKEN_MFA_CODE": response.code],
            session: response.session
        )
    }

    /// Enable MFA support
    func enableMfa(
        _ request: Request,
        context: Context
    ) async throws -> HTTPResponse.Status {
        guard case .accessToken(let token) = context.identity else {
            throw HTTPError(.unauthorized)
        }
        let setUserMfaRequest = CognitoIdentityProvider.AdminSetUserMFAPreferenceRequest(
            softwareTokenMfaSettings: .init(
                enabled: true,
                preferredMfa: true
            ),
            username: token.username,
            userPoolId: self.cognitoAuthenticatable.configuration.userPoolId
        )
        _ = try await self.cognitoIdentityProvider.adminSetUserMFAPreference(
            setUserMfaRequest
        )
        return .ok
    }

    /// Disable MFA support
    func disableMfa(
        _ request: Request,
        context: Context
    ) async throws -> HTTPResponse.Status {
        struct Password: Decodable {
            let password: String
        }
        guard case .accessToken(let token) = context.identity else {
            throw HTTPError(.unauthorized)
        }
        let password = try await request.decode(
            as: Password.self,
            context: context
        )

        _ = try await self.cognitoAuthenticatable.authenticate(
            username: token.username,
            password: password.password
        )
        let setUserMfaRequest = CognitoIdentityProvider.AdminSetUserMFAPreferenceRequest(
            softwareTokenMfaSettings: .init(
                enabled: false,
                preferredMfa: false
            ),
            username: token.username,
            userPoolId: self.cognitoAuthenticatable.configuration.userPoolId
        )
        _ = try await self.cognitoIdentityProvider.adminSetUserMFAPreference(
            setUserMfaRequest
        )
        return .ok
    }
}
