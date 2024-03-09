import Hummingbird
import HummingbirdAuth
import Logging
import NIOCore

struct TodosAuthRequestContext: HBAuthRequestContext {
    var coreContext: HBCoreRequestContext
    var auth: HBLoginCache

    init(channel: Channel, logger: Logger) {
        self.coreContext = .init(allocator: channel.allocator, logger: logger)
        self.auth = .init()
    }

    var requestDecoder: RequestDecoder {
        RequestDecoder()
    }
}
