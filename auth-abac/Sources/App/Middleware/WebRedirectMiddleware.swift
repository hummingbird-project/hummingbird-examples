import Hummingbird

/// Redirects unauthenticated web requests to the login page.
/// Checks `context.currentUser` (set by `WebSessionMiddleware`) rather than `context.identity`.
struct WebRedirectMiddleware: RouterMiddleware {
    typealias Context = AppRequestContext
    let to: String

    func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        if context.currentUser != nil {
            return try await next(request, context)
        } else {
            return .redirect(to: "\(self.to)?from=\(request.uri)", type: .found)
        }
    }
}
