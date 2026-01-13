import Hummingbird
import HummingbirdWebSocket
import Logging
import Valkey

/// Application arguments protocol. We use a protocol so we can call
/// `buildApplication` inside Tests as well as in the App executable.
/// Any variables added here also have to be added to `App` in App.swift and
/// `TestArguments` in AppTest.swift
public protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var maxAgeOfLoadedMessages: Int { get }
}
extension AppArguments {
    // default to 10 minutes
    var maxAgeOfLoadedMessages: Int { 600 }
}

// Request context used by application
typealias AppRequestContext = BasicRequestContext

///  Build application
/// - Parameter arguments: application arguments
public func buildApplication(_ arguments: some AppArguments) async throws -> some ApplicationProtocol {
    var logger = Logger(label: "valkey-chat")
    logger.logLevel = .trace

    // Valkey client
    let valkey = ValkeyClient(.hostname("127.0.0.1"), logger: logger)

    let router = buildRouter()
    let wsRouter = buildWebSocketRouter(valkey: valkey, arguments: arguments)
    let app = Application(
        router: router,
        server: .http1WebSocketUpgrade(webSocketRouter: wsRouter),
        configuration: .init(
            address: .hostname(arguments.hostname, port: arguments.port),
            serverName: "valkey-chat"
        ),
        services: [valkey],
        logger: logger
    )
    return app
}

/// Build router
func buildRouter() -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    // Add middleware
    router.addMiddleware {
        // logging middleware
        LogRequestsMiddleware(.info)
        // file middleware
        FileMiddleware(searchForIndexHtml: true)
    }
    return router
}

/// Build websocket router
func buildWebSocketRouter(valkey: ValkeyClient, arguments: some AppArguments) -> Router<BasicWebSocketRequestContext> {
    let router = Router(context: BasicWebSocketRequestContext.self)
    router.add(middleware: LogRequestsMiddleware(.debug))
    router.addRoutes(ChatController(valkey: valkey, maxAgeOfLoadedMessages: arguments.maxAgeOfLoadedMessages).routes)
    return router
}
