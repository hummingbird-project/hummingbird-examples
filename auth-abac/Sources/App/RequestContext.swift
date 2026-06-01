import Foundation
import Hummingbird
import HummingbirdAuth

/// The application request context.
///
/// Two-stage identity assembly for API routes:
/// 1. ``UserAuthenticatorMiddleware`` verifies Basic auth credentials → `authenticatedUser`.
/// 2. ``DocumentResolverMiddleware`` / ``UserIdentityMiddleware`` assembles the full ``DocumentRequest``.
///
/// For web UI routes, `sessions` + `currentUser` are used instead (set by ``WebSessionMiddleware``).
struct AppRequestContext: AuthRequestContext, SessionRequestContext, RequestContext {
    typealias Identity = DocumentRequest

    var coreContext: CoreRequestContextStorage

    /// The ``AuthRequestContext`` identity (used by ABAC API routes).
    var identity: DocumentRequest?

    /// Staging field for API routes: authenticated ``User`` before document resolution.
    var authenticatedUser: User?

    // MARK: - Web UI session support

    /// Session value — stores the logged-in user's UUID for web routes.
    var sessions: SessionContext<UUID>

    /// The web-authenticated user (resolved from session by ``WebSessionMiddleware``).
    var currentUser: User?

    init(source: Source) {
        self.coreContext = .init(source: source)
        self.identity = nil
        self.authenticatedUser = nil
        self.sessions = .init()
        self.currentUser = nil
    }

    var requestDecoder: AppRequestDecoder { AppRequestDecoder() }
}
