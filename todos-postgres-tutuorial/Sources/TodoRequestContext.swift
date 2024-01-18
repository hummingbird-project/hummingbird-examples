import Hummingbird
import HummingbirdFoundation
import Logging

/// Custom request context setting up JSON decoding and encoding
struct TodoRequestContext: HBRequestContext {
    var coreContext: HBCoreRequestContext
    var requestDecoder: JSONDecoder { .init() }
    var responseEncoder: JSONEncoder { .init() }

    init(allocator: ByteBufferAllocator, logger: Logger) {
        self.coreContext = .init(
            allocator: allocator,
            logger: logger
        )
    }
}
