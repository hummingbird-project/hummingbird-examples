import Hummingbird
import Logging
import Mustache
import NIOCore

struct HTMLFormRequestContext: RequestContext {
    var coreContext: CoreRequestContextStorage

    init(source: Source) {
        self.coreContext = .init(source: source)
    }

    var requestDecoder: URLFormRequestDecoder { .init() }
}

/// Application arguments protocol. We use a protocol so we can call
/// `buildApplication` inside Tests as well as in the App executable.
/// Any variables added here also have to be added to `App` in App.swift and
/// `TestArguments` in AppTest.swift
public protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var logLevel: Logger.Level? { get }
}

public func buildApplication(args: AppArguments) async throws -> some ApplicationProtocol {
    let logger = {
        var logger = Logger(label: "html-form")
        logger.logLevel = args.logLevel ?? .info
        return logger
    }()
    let library = try await MustacheLibrary(directory: "resources/templates")
    assert(library.getTemplate(named: "page") != nil, "Set your working directory to the root folder of this example to get it to work")

    let router = Router(context: HTMLFormRequestContext.self)
    router.middlewares.add(FileMiddleware())
    WebController(mustacheLibrary: library).addRoutes(to: router)
    let app = Application(
        router: router,
        configuration: .init(address: .hostname(args.hostname, port: args.port)),
        logger: logger
    )
    return app
}
