import Hummingbird
import HummingbirdAuth
import Logging
import NIOCore

struct TodosAuthRequestContext: AuthRequestContext, BaseRequestContext, RequestContext {
    var coreContext: CoreRequestContext
    var auth: LoginCache

    init(channel: Channel, logger: Logger) {
        self.coreContext = .init(allocator: channel.allocator, logger: logger)
        self.auth = .init()
    }

    var requestDecoder: TodosAuthRequestDecoder {
        TodosAuthRequestDecoder()
    }
}
