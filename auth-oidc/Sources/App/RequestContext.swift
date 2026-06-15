import Hummingbird
import HummingbirdAuth

// Request context used by application
struct AppRequestContext: SessionRequestContext, RequestContext {
    enum Session: Sendable, Codable {
        struct OIDCSession: Sendable, Codable {
            let state: String
            let nonce: String
        }
        struct AuthenticatedState: Sendable, Codable {
            let id: String
            let name: String
            let accessToken: String
            let idToken: String?
            let refreshToken: String?
        }
        case oidc(OIDCSession)
        case authenticated(AuthenticatedState)

        var oidcSession: OIDCSession? {
            guard case .oidc(let session) = self else { return nil }
            return session
        }

        var authenticatedState: AuthenticatedState? {
            guard case .authenticated(let state) = self else { return nil }
            return state
        }
    }

    let sessions: SessionContext<Session>

    var coreContext: CoreRequestContextStorage

    init(source: Hummingbird.ApplicationRequestContextSource) {
        self.sessions = .init()
        self.coreContext = .init(source: source)
    }
}
