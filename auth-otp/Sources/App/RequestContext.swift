import Hummingbird
import HummingbirdAuth

typealias AppRequestContext = BasicRequestContext

/// Request context for endpoints that require sessions
struct AppSessionRequestContext: SessionRequestContext, AuthRequestContext {
    typealias Session = App.Session
    typealias Source = AppRequestContext

    var sessions: SessionContext<Session>
    var auth: LoginCache
    var coreContext: CoreRequestContextStorage

    init(source: Source) {
        self.coreContext = source.coreContext
        self.auth = .init()
        self.sessions = .init()
    }
}
