import Hummingbird
import HummingbirdAuth

typealias AppRequestContext = BasicRequestContext

/// Request context for endpoints that require sessions
struct AppSessionRequestContext: SessionRequestContext, AuthRequestContext, ChildRequestContext {
    typealias Session = App.Session

    var sessions: SessionContext<Session>
    var identity: User?
    var coreContext: CoreRequestContextStorage

    init(context: AppRequestContext) {
        self.coreContext = context.coreContext
        self.identity = nil
        self.sessions = .init()
    }
}

/// Request context for endpoints that require an authenticated user
struct AuthenticatedRequestContext: ChildRequestContext {
    var coreContext: CoreRequestContextStorage
    let user: User

    init(context: AppSessionRequestContext) throws {
        self.coreContext = context.coreContext
        self.user = try context.requireIdentity()
    }
}
