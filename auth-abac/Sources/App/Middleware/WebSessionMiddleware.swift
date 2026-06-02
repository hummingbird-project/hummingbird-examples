import FluentKit
import Hummingbird
import HummingbirdFluent

/// Reads the UUID session cookie and resolves it to a `User`, storing the result
/// in `context.currentUser` for use by web route handlers.
///
/// Must run after `SessionMiddleware` in the middleware stack.
/// API routes that do not use sessions are unaffected.
struct WebSessionMiddleware: RouterMiddleware {
    typealias Context = AppRequestContext
    let fluent: Fluent

    func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        var context = context
        if let userId = context.sessions.session {
            context.currentUser = try await User.find(userId, on: fluent.db())
        }
        return try await next(request, context)
    }
}
