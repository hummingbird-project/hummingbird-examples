import Hummingbird
import HummingbirdMustache
import Logging
import NIOCore

struct HTMLFormRequestContext: HBRequestContext {
    var coreContext: HBCoreRequestContext

    init(allocator: ByteBufferAllocator, logger: Logger) {
        self.coreContext = .init(
            requestDecoder: RequestDecoder(),
            allocator: allocator,
            logger: logger
        )
    }
}

public func buildApplication(configuration: HBApplicationConfiguration) async throws -> some HBApplicationProtocol {
    let library = try HBMustacheLibrary(directory: "templates")
    assert(library.getTemplate(named: "head") != nil, "Set your working directory to the root folder of this example to get it to work")

    let router = HBRouter(context: HTMLFormRequestContext.self)
    WebController(mustacheLibrary: library).addRoutes(to: router)
    let app = HBApplication(router: router)
    return app
}
