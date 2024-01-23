import Hummingbird
import SotoCognitoAuthenticationKit
import SotoCore

/// Output AWS error messages to user
struct AWSErrorMiddleware<Context: HBRequestContext>: HBMiddlewareProtocol {
    func handle(_ request: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse {
        do {
            return try await next(request, context)
        } catch let error as AWSErrorType {
            throw HBHTTPError(.internalServerError, message: "Code: \(error.errorCode), Message: \(error.message ?? "No message")")
        } catch let error as SotoCognitoError {
            throw switch error {
            case .unexpectedResult(let message):
                HBHTTPError(.internalServerError, message: "Unexpected result: \(message ?? "")")
            case .unauthorized(let message):
                HBHTTPError(.internalServerError, message: "Unauthorized: \(message ?? "")")
            case .invalidPublicKey:
                HBHTTPError(.internalServerError, message: "Invalid public key")
            }
        }
    }
}
