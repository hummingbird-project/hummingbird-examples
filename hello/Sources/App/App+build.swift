import Configuration
import Hummingbird
import Logging

// Request context used by application
typealias AppRequestContext = BasicRequestContext

///  Build application
/// - Parameter reader: configuration reader
func buildApplication(reader: ConfigReader) async throws -> some ApplicationProtocol {
    let logger = {
        var logger = Logger(label: "hello")
        logger.logLevel = reader.string(forKey: "log.level", as: Logger.Level.self, default: .info)
        return logger
    }()
    let router = try buildRouter()
    let app = Application(
        router: router,
        configuration: ApplicationConfiguration(reader: reader.scoped(to: "http")),
        logger: logger
    )
    return app
}

/// Build router
func buildRouter() throws -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    // Add middleware
    router.addMiddleware {
        // logging middleware
        LogRequestsMiddleware(.info)
    }
    // Add default endpoint
    router.get("/") { _,_ in
        return "Hello!"
    }
    return router
}
