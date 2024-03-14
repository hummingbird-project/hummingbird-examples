import Hummingbird
import SotoCognitoAuthenticationKit
import SotoCore

/// Output AWS error messages to user
struct AWSErrorMiddleware<Context: RequestContext>: RouterMiddleware {
    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        do {
            return try await next(request, context)
        } catch let error as AWSErrorType {
            throw HTTPError(.internalServerError, message: "Code: \(error.errorCode), Message: \(error.message ?? "No message")")
        } catch let error as SotoCognitoError {
            throw switch error {
            case .unexpectedResult(let message):
                HTTPError(.internalServerError, message: "Unexpected result: \(message ?? "")")
            case .unauthorized(let message):
                HTTPError(.internalServerError, message: "Unauthorized: \(message ?? "")")
            case .invalidPublicKey:
                HTTPError(.internalServerError, message: "Invalid public key")
            }
        }
    }
}
