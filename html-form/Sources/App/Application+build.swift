import Hummingbird
import HummingbirdMustache
import Logging
import NIOCore

struct HTMLFormRequestContext: RequestContext {
    var coreContext: CoreRequestContext

    init(channel: Channel, logger: Logger) {
        self.coreContext = .init(allocator: channel.allocator, logger: logger)
    }

    var requestDecoder: URLFormRequestDecoder { .init() }
}

public func buildApplication(configuration: ApplicationConfiguration) async throws -> some ApplicationProtocol {
    let library = try await MustacheLibrary(directory: "templates")
    assert(library.getTemplate(named: "head") != nil, "Set your working directory to the root folder of this example to get it to work")

    let router = Router(context: HTMLFormRequestContext.self)
    WebController(mustacheLibrary: library).addRoutes(to: router)
    let app = Application(router: router)
    return app
}
