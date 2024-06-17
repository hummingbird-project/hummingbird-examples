import Hummingbird
import HummingbirdAuth
import HummingbirdRouter
import Logging
import NIOCore

struct WebAuthnRequestContext: AuthRequestContext, RouterRequestContext, RequestContext {
    var coreContext: CoreRequestContextStorage
    var auth: LoginCache
    var routerContext: RouterBuilderContext

    init(source: Source) {
        self.coreContext = .init(source: source)
        self.auth = .init()
        self.routerContext = .init()
    }
}
