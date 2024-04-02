import Hummingbird
import HummingbirdWebSocket
import HummingbirdWSCompression
import Logging

protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
}

func buildApplication(_ arguments: some AppArguments) async throws -> some ApplicationProtocol {
    var logger = Logger(label: "WebSocketEcho")
    logger.logLevel = .debug

    // Router
    let router = Router()
    router.middlewares.add(LogRequestsMiddleware(.debug))
    router.middlewares.add(FileMiddleware(logger: logger))

    // Separate router for websocket upgrade
    let wsRouter = Router(context: BasicWebSocketRequestContext.self)
    wsRouter.middlewares.add(LogRequestsMiddleware(.debug))
    wsRouter.ws("echo") { _, _ in
        .upgrade([:])
    } onUpgrade: { inbound, outbound, _ in
        for try await packet in inbound {
            if case .text("disconnect") = packet {
                break
            }
            try await outbound.write(.custom(packet.webSocketFrame))
        }
    }

    let app = Application(
        router: router,
        server: .webSocketUpgrade(webSocketRouter: wsRouter, configuration: .init(extensions: [.perMessageDeflate()])),
        configuration: .init(address: .hostname(arguments.hostname, port: arguments.port)),
        logger: logger
    )
    return app
}
