import Hummingbird
import Logging
import NIOCore

struct MultipartRequestContext: RequestContext {
    var requestDecoder: MultipartRequestDecoder { .init() }
    var coreContext: CoreRequestContext

    init(channel: Channel, logger: Logger) {
        self.coreContext = .init(allocator: channel.allocator, logger: logger)
    }
}
