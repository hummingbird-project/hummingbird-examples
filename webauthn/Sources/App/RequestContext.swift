import Hummingbird
import HummingbirdAuth
import HummingbirdRouter
import Logging
import NIOCore

struct WebAuthnRequestContext: HBAuthRequestContext, HBRouterRequestContext {
    var coreContext: HBCoreRequestContext
    var auth: HBLoginCache
    var routerContext: HBRouterBuilderContext

    init(allocator: ByteBufferAllocator, logger: Logger) {
        self.coreContext = .init(allocator: allocator, logger: logger)
        self.auth = .init()
        self.routerContext = .init()
    }
}
