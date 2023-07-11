import Hummingbird
import HummingbirdFoundation
import HummingbirdWebSocket

extension HBApplication {
    /// configure your application
    /// add middleware
    /// setup the encoder/decoder
    /// add your routes
    public func configure() throws {
        self.logger.logLevel = .trace
        // server html
        self.middleware.add(HBFileMiddleware(application: self))
        // add HTTP to WebSocket upgrade
        self.ws.addUpgrade(maxFrameSize: 1 << 14)
        // add middleware to websocket initial requests
        self.ws.add(middleware: HBLogRequestsMiddleware(.info))
        // on websocket connect.
        self.ws.on(
            "/echo",
            shouldUpgrade: { _ in return nil },
            onUpgrade: { _, ws -> HTTPResponseStatus in
                // send ping and wait for pong and repeat every 60 seconds
                ws.initiateAutoPing(interval: .seconds(60))
                ws.onRead { frame, ws in
                    ws.write(frame, promise: nil)
                }
                return .ok
            }
        )
    }
}
