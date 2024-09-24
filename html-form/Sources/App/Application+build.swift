import Foundation
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
    // Verify the working directory is correct
    assert(FileManager.default.fileExists(atPath: "public/images/hummingbird.png"), "Set your working directory to the root folder of this example to get it to work")
    // load mustache template library
    let library = try await MustacheLibrary(directory: Bundle.module.resourcePath!)

    let router = Router(context: HTMLFormRequestContext.self)
    router.add(middleware: FileMiddleware())
    WebController(mustacheLibrary: library).addRoutes(to: router)
    let app = Application(
        router: router,
        configuration: .init(address: .hostname(args.hostname, port: args.port)),
        logger: logger
    )
    return app
}
