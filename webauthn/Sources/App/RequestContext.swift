import Hummingbird
import HummingbirdAuth
import HummingbirdRouter
import Logging
import NIOCore

struct WebAuthnRequestContext: AuthRequestContext, RouterRequestContext, SessionRequestContext {
    var coreContext: CoreRequestContextStorage
    var auth: LoginCache
    var routerContext: RouterBuilderContext
    let sessions: SessionContext<WebAuthnSession>

    init(source: Source) {
        self.coreContext = .init(source: source)
        self.auth = .init()
        self.routerContext = .init()
        self.sessions = .init()
    }
}
