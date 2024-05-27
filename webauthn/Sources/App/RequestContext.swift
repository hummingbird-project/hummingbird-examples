import Hummingbird
import HummingbirdAuth
import HummingbirdRouter
import Logging
import NIOCore

struct WebAuthnRequestContext: AuthRequestContext, RouterRequestContext, RequestContext {
    var coreContext: CoreRequestContext
    var auth: LoginCache
    var routerContext: RouterBuilderContext

    init(channel: Channel, logger: Logger) {
        self.coreContext = .init(allocator: channel.allocator, logger: logger)
        self.auth = .init()
        self.routerContext = .init()
    }
}
