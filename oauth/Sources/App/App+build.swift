import Configuration
import Foundation
import Hummingbird
import HummingbirdAuth
import Logging
import Mustache
import OAuthKit

///  Build application
/// - Parameter reader: configuration reader
func buildApplication(reader: ConfigReader) async throws -> some ApplicationProtocol {
    let logger = {
        var logger = Logger(label: "oauth")
        logger.logLevel = reader.string(forKey: "log.level", as: Logger.Level.self, default: .info)
        return logger
    }()

    let persistDriver = MemoryPersistDriver()
    // load mustache template library
    let library = try await MustacheLibrary(directory: Bundle.module.resourcePath!)

    let router = try await buildRouter(reader: reader, logger: logger, persistDriver: persistDriver, library: library)
    let app = Application(
        router: router,
        configuration: ApplicationConfiguration(reader: reader.scoped(to: "http")),
        logger: logger
    )
    return app
}

/// Build router
func buildRouter(
    reader: ConfigReader,
    logger: Logger,
    persistDriver: some PersistDriver,
    library: MustacheLibrary
) async throws -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    // Add middleware
    router.addMiddleware {
        // logging middleware
        LogRequestsMiddleware(.info)
        // file serving middleware
        FileMiddleware()
        // session middleware
        SessionMiddleware(
            storage: persistDriver,
            configuration: .init(
                sessionCookieParameters: .init(sameSite: .lax),
                keyPrefix: "Session/",
                defaultSessionExpiration: .seconds(1 * 60 * 60)
            )
        )
    }
    router.addRoutes(WebController(library: library).routes)
    try await router.addRoutes(OIDCController(config: reader.scoped(to: "oidc"), logger: logger).routes)
    return router
}
