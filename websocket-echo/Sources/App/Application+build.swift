import Hummingbird
import HummingbirdWebSocket
import HummingbirdWSCompression
import Logging
import NIOWebSocket

protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
}

func buildApplication(_ arguments: some AppArguments) async throws -> some ApplicationProtocol {
    var logger = Logger(label: "WebSocketEcho")
    logger.logLevel = .debug

    // Router
    let router = Router()
    router.add(middleware: LogRequestsMiddleware(.debug))
    router.add(middleware: FileMiddleware(logger: logger))

    // Separate router for websocket upgrade
    let wsRouter = Router(context: BasicWebSocketRequestContext.self)
    wsRouter.add(middleware: LogRequestsMiddleware(.debug))
    wsRouter.ws("echo") { _, _ in
        .upgrade([:])
    } onUpgrade: { inbound, outbound, _ in
        // parse WebSocket frames
        for try await frame in inbound {
            if frame.opcode == .text, String(buffer: frame.data) == "disconnect", frame.fin == true {
                break
            }
            let opcode: WebSocketOpcode = switch frame.opcode {
            case .text: .text
            case .binary: .binary
            case .continuation: .continuation
            }
            let frame = WebSocketFrame(
                fin: frame.fin,
                opcode: opcode,
                data: frame.data
            )
            try await outbound.write(.custom(frame))
        }
    }

    let app = Application(
        router: router,
        server: .http1WebSocketUpgrade(webSocketRouter: wsRouter, configuration: .init(extensions: [.perMessageDeflate()])),
        configuration: .init(address: .hostname(arguments.hostname, port: arguments.port)),
        logger: logger
    )
    return app
}
