import Hummingbird
import HummingbirdAuth
import Logging
import NIOCore

struct TodosAuthRequestContext: HBAuthRequestContext {
    var coreContext: HBCoreRequestContext
    var auth: HBLoginCache

    init(allocator: ByteBufferAllocator, logger: Logger) {
        self.coreContext = .init(allocator: allocator, logger: logger)
        self.auth = .init()
    }

    var requestDecoder: RequestDecoder {
        RequestDecoder()
    }
}
