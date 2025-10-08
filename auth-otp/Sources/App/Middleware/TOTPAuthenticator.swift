import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdAuth
import HummingbirdOTP

struct TOTPAuthenticator<Users: UserRepository>: AuthenticatorMiddleware {
    typealias Context = AppSessionRequestContext
    public let users: Users

    /// Initialize BasicAuthenticator middleware
    /// - Parameters:
    ///   - users: User repository
    ///   - passwordHashVerifier: password verifier
    ///   - context: Request context type
    init(users: Users) {
        self.users = users
    }

    func authenticate(request: Request, context: Context) async throws -> Users.User? {
        guard let session = context.sessions.session else { return nil }
        // if current session is waiting on challenge response
        if case .challenge(let challenge) = session, case .totp(let userID) = challenge {
            // get authorization header and extract "totp" token if available
            guard let authorization = request.headers[.authorization] else { return nil }
            guard authorization.hasPrefix("totp ") else { return nil }
            let totpCode = authorization.dropFirst("totp ".count)
            // get user for session
            guard let user = try await users.getUser(id: userID, logger: context.logger) else {
                throw HTTPError(.unauthorized, message: "User hasn't setup TOTP token")
            }
            // get user OTP secret and compute current TOTP and next TOTP tokens
            guard let otpSecret = user.otpSecret else { return nil }
            let code = Int(totpCode)
            let computedTOTP = TOTP(secret: otpSecret).compute(date: .now - 15.0)
            let computedTOTP2 = TOTP(secret: otpSecret).compute(date: .now + 15.0)
            // if provided token is not equal to one of the computed tokens then fail
            guard code == computedTOTP || code == computedTOTP2 else {
                return nil
            }
            // save an authenticated user to the session
            context.sessions.setSession(.authenticated(userID))
            return user
        }
        return nil
    }
}

extension HTTPField.Name {
    static var challenge: Self { .init("challenge")! }
    static var otpSession: Self { .init("otp-session")! }
}
