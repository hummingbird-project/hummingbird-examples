import Hummingbird
import HummingbirdAuth
import HummingbirdRouter
import Logging
import NIOCore

struct WebAuthnRequestContext: HBAuthRequestContext, HBRouterRequestContext {
    var coreContext: HBCoreRequestContext
    var auth: HBLoginCache
    var routerContext: HBRouterBuilderContext

    init(channel: Channel, logger: Logger) {
        self.coreContext = .init(allocator: channel.allocator, logger: logger)
        self.auth = .init()
        self.routerContext = .init()
    }
}
