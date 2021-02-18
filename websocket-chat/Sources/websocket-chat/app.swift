import Hummingbird
import HummingbirdFoundation

func runApp(_ arguments: HummingbirdArguments) {
    let app = HBApplication(configuration: .init(address: .hostname(arguments.hostname, port: arguments.port)))
    // add HTTP to WebSocket upgrade
    app.ws.addUpgrade()
    // add middleware to websocket initial requests
    app.ws.add(middleware: HBLogRequestsMiddleware(.info))
    // on websocket connect.
    app.ws.on(
        "/chat",
        shouldUpgrade: { request in
            guard request.uri.queryParameters["username"] != nil else {
                return request.failure(.badRequest)
            }
            return request.success([:])
        },
        onUpgrade: { request, ws in
            guard let username = request.uri.queryParameters["username"] else {
                ws.close(promise: nil)
                throw HBHTTPError(.badRequest)
            }
            guard request.application.connectionMgr.get(name: String(username)) == nil else {
                ws.write(.text("\(username) is already connected"))
                ws.close(promise: nil)
                return
            }
            request.application.connectionMgr.newUser(name: String(username), ws: ws)
        }
    )
    app.connectionMgr = .init()
    
    app.start()
    app.wait()
}
