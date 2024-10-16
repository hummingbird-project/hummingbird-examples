import Hummingbird
import HummingbirdAuth

/// Redirects to login page if no user has been authenticated
struct RedirectMiddleware<Context: AuthRequestContext>: RouterMiddleware {
    let to: String
    func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Output
    ) async throws -> Response {
        if context.identity != nil {
            return try await next(request, context)
        } else {
            return .redirect(to: "\(self.to)?from=\(request.uri)", type: .found)
        }
    }
}
