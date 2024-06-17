import Hummingbird
import Logging
import NIOCore

struct MultipartRequestContext: RequestContext {
    var requestDecoder: MultipartRequestDecoder { .init() }
    var coreContext: CoreRequestContextStorage

    init(source: Source) {
        self.coreContext = .init(source: source)
    }
}
