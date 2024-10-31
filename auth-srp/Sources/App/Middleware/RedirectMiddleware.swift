import Hummingbird
import HummingbirdAuth

/// Middleware returning 404 for unauthenticated requests
public struct RedirectMiddleware<Context: AuthRequestContext>: RouterMiddleware {
    public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        do {
            let response = try await next(request, context)
            return response
        } catch let error as HTTPError {
            // redirect for unauthorized or not found status
            if error.status == .unauthorized || error.status == .notFound, request.method == .get {
                return .redirect(to: "/login.html", type: .temporary)
            } else {
                throw error
            }
        }
    }
}
