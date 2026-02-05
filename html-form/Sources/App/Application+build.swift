import Configuration
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

///  Build application
/// - Parameter reader: configuration reader
func buildApplication(reader: ConfigReader) async throws -> some ApplicationProtocol {
    let logger = {
        var logger = Logger(label: "hello")
        logger.logLevel = reader.string(forKey: "log.level", as: Logger.Level.self, default: .info)
        return logger
    }()
    // Verify the working directory is correct
    assert(
        FileManager.default.fileExists(atPath: "public/images/hummingbird.png"),
        "Set your working directory to the root folder of this example to get it to work"
    )
    // load mustache template library
    let library = try await MustacheLibrary(directory: Bundle.module.resourcePath!)

    let router = Router(context: HTMLFormRequestContext.self)
    router.add(middleware: FileMiddleware())
    WebController(mustacheLibrary: library).addRoutes(to: router)
    let app = Application(
        router: router,
        configuration: ApplicationConfiguration(reader: reader.scoped(to: "http")),
        logger: logger
    )
    return app
}
