import Hummingbird
import HummingbirdAuth
import HummingbirdRouter
import Logging
import NIOCore

struct WebAuthnRequestContext: AuthRequestContext, RouterRequestContext, SessionRequestContext {
    var coreContext: CoreRequestContextStorage
    var identity: User?
    var routerContext: RouterBuilderContext
    let sessions: SessionContext<WebAuthnSession>

    init(source: Source) {
        self.coreContext = .init(source: source)
        self.identity = nil
        self.routerContext = .init()
        self.sessions = .init()
    }
}
