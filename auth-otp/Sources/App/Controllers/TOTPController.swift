import Foundation
import Hummingbird
import HummingbirdAuth
import OTP

struct TOTPVerificationSession: Codable {
    let secret: String
    var verified: Bool
}

struct TOTPController<Users: UserRepository, Storage: PersistDriver> {
    let users: Users
    let storage: Storage

    var endpoints: RouteCollection<AppRequestContext> {
        let routes = RouteCollection(context: AppRequestContext.self)
        routes
            .group("users/totp", context: AppSessionRequestContext.self)
            .addMiddleware {
                SessionMiddleware(storage: self.storage)
                SessionAuthenticator(users: self.users)
            }
            .post("start") { request, context -> EditedResponse<String> in
                let otpSecret = UUID().uuidString
                let otpSetupSession = UUID().uuidString
                try await self.storage.create(key: otpSetupSession, value: TOTPVerificationSession(secret: otpSecret, verified: false), expires: .seconds(60 * 10))
                return .init(
                    headers: [.otpSession: otpSetupSession],
                    response: TOTP(secret: otpSecret).createAuthenticatorURL(label: "auth-otp")
                )
            }
            .post("verify/{code}") { request, context -> HTTPResponse.Status in
                let code = try context.parameters.require("code", as: Int.self)
                guard let otpSession = request.headers[.otpSession] else { return .badRequest }
                guard var otpVerificationSession = try await self.storage.get(key: otpSession, as: TOTPVerificationSession.self) else { return .notFound }
                let computedTOTP = TOTP(secret: otpVerificationSession.secret).compute(date: .now - 15.0)
                let computedTOTP2 = TOTP(secret: otpVerificationSession.secret).compute(date: .now + 15.0)
                guard code == computedTOTP || code == computedTOTP2 else {
                    return .unauthorized
                }
                otpVerificationSession.verified = true
                try await self.storage.set(key: otpSession, value: otpVerificationSession)
                return .ok
            }
            .post("complete") { request, context -> HTTPResponse.Status in
                let user = try context.auth.require(User.self)
                guard let otpSession = request.headers[.otpSession] else { return .badRequest }
                guard let otpVerificationSession = try await self.storage.get(key: otpSession, as: TOTPVerificationSession.self) else {
                    return .notFound
                }
                guard otpVerificationSession.verified else {
                    return .badRequest
                }
                try await self.users.addTOTP(userID: user.id, secret: otpVerificationSession.secret, logger: context.logger)
                return .ok
            }
            .delete { request, context -> HTTPResponse.Status in
                let user = try context.auth.require(User.self)
                guard user.otpSecret != nil else { return .ok }
                try await self.users.removeTOTP(userID: user.id, logger: context.logger)
                return .ok
            }
            .get { request, context in
                let user = try context.auth.require(User.self)
                guard let secret = user.otpSecret else { throw HTTPError(.noContent) }
                return TOTP(secret: secret).createAuthenticatorURL(label: "auth-otp")
            }
        return routes
    }
}
