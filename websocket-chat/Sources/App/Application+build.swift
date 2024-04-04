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

    // Router
    let router = Router()
    router.middlewares.add(LogRequestsMiddleware(.debug))
    router.middlewares.add(FileMiddleware(logger: logger))

    // Separate router for websocket upgrade
    let wsRouter = Router(context: BasicWebSocketRequestContext.self)
    wsRouter.middlewares.add(LogRequestsMiddleware(.debug))
    wsRouter.ws("chat") { request, _ in
        // only allow upgrade if username query parameter exists
        guard request.uri.queryParameters["username"] != nil else {
            return .dontUpgrade
        }
        return .upgrade([:])
    } onUpgrade: { inbound, outbound, context in
        // only allow upgrade if username query parameter exists
        guard let name = context.request.uri.queryParameters["username"] else {
            return
        }
        await connectionManager.manageUser(name: String(name), inbound: inbound, outbound: outbound)
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

/* extension HBApplication {
     /// configure your application
     /// add middleware
     /// setup the encoder/decoder
     /// add your routes
     public func configure() throws {
         // server html
         self.middleware.add(HBFileMiddleware(application: self))
         // add HTTP to WebSocket upgrade
         self.ws.addUpgrade()
         // add middleware to websocket initial requests
         self.ws.add(middleware: HBLogRequestsMiddleware(.info))
         // on websocket connect.
         self.ws.on(
             "/chat",
             shouldUpgrade: { request -> HTTPHeaders? in
                 // only allow upgrade if username query parameter exists
                 guard request.uri.queryParameters["username"] != nil else {
                     throw HBHTTPError(.badRequest)
                 }
                 return nil
             },
             onUpgrade: { request, ws -> HTTPResponseStatus in
                 // close websocket if no username parameter
                 guard let username = request.uri.queryParameters["username"] else {
                     try await ws.close()
                     return .badRequest
                 }
                 // if username is already connected output this info and close the connection
                 guard await request.application.connectionMgr.get(name: String(username)) == nil else {
                     try await ws.write(.text("\(username) is already connected"))
                     try await ws.close()
                     return .conflict
                 }
                 // add new user
                 await request.application.connectionMgr.newUser(name: String(username), ws: ws)
                 return .ok
             }
         )
         // initialize connection manager
         self.connectionMgr = .init()
     }
 } */
