import Hummingbird
import HummingbirdAuth

typealias AppRequestContext = BasicRequestContext

/// Request context for endpoints that require sessions
struct AppSessionRequestContext: SessionRequestContext, AuthRequestContext {
    typealias Session = App.Session
    typealias Source = AppRequestContext

    var sessions: SessionContext<Session>
    var identity: User?
    var coreContext: CoreRequestContextStorage

    init(source: Source) {
        self.coreContext = source.coreContext
        self.identity = nil
        self.sessions = .init()
    }
}
