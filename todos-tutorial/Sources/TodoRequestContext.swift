import Hummingbird
import HummingbirdFoundation
import Logging


/// Custom request context setting up JSON decoding and encoding
struct TodoRequestContext: HBRequestContext {
    var coreContext: HBCoreRequestContext


    init(allocator: ByteBufferAllocator, logger: Logger) {
        self.coreContext = .init(
            requestDecoder: JSONDecoder(),
            responseEncoder: JSONEncoder(),
            allocator: allocator,
            logger: logger
        )
    }
}