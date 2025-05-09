import Foundation
import Hummingbird
import HummingbirdWebSocket
import HummingbirdWSCompression
import Logging
import ServiceLifecycle

protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
}

func buildApplication(_ arguments: some AppArguments) async throws -> some ApplicationProtocol {
    var logger = Logger(label: "WebSocketChat")
    logger.logLevel = .trace
    let connectionManager = ConnectionManager(logger: logger)

    // Create a router for the HTTP server
    let router = Router()
    router.add(middleware: LogRequestsMiddleware(.debug))
    router.add(middleware: FileMiddleware(logger: logger))

    // Separate router for websocket upgrade
    let wsRouter = Router(context: BasicWebSocketRequestContext.self)
    wsRouter.add(middleware: LogRequestsMiddleware(.debug))
    wsRouter.ws("chat") { request, _ in
        // only allow upgrade if username query parameter exists
        guard request.uri.queryParameters["username"] != nil else {
            return .dontUpgrade
        }
        return .upgrade([:])
    } onUpgrade: { inbound, outbound, context in
        // only allow upgrade if username query parameter exists
        guard let name = context.request.uri.queryParameters["username"] else {
            try await outbound.close(.unexpectedServerError, reason: "User is not authenticated")
            return
        }
        let outputStream = connectionManager.addUser(name: String(name), inbound: inbound, outbound: outbound)
        for try await output in outputStream {
            switch output {
            case .frame(let frame):
                try await outbound.write(frame)
            case .close(let reason):
                try await outbound.close(.unexpectedServerError, reason: reason)
            }
        }
    }

    var app = Application(
        router: router,
        server: .http1WebSocketUpgrade(webSocketRouter: wsRouter, configuration: .init(extensions: [.perMessageDeflate()])),
        configuration: .init(address: .hostname(arguments.hostname, port: arguments.port)),
        logger: logger
    )
    app.addServices(connectionManager)
    return app
}
