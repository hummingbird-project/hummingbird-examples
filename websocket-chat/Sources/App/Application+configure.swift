import Hummingbird
import HummingbirdFoundation

extension HBApplication {
    /// configure your application
    /// add middleware
    /// setup the encoder/decoder
    /// add your routes
    public func configure() throws {
        self.middleware.add(HBFileMiddleware(application: self))
        // add HTTP to WebSocket upgrade
        self.ws.addUpgrade()
        // add middleware to websocket initial requests
        self.ws.add(middleware: HBLogRequestsMiddleware(.info))
        // on websocket connect.
        self.ws.on(
            "/chat",
            shouldUpgrade: { request in
                // only allow upgrade if username query parameter exists
                guard request.uri.queryParameters["username"] != nil else {
                    return request.failure(.badRequest)
                }
                return request.success([:])
            },
            onUpgrade: { request, ws in
                // close websocket if no username parameter
                guard let username = request.uri.queryParameters["username"] else {
                    ws.close(promise: nil)
                    return
                }
                // if username is already connected output this info and close the connection
                guard request.application.connectionMgr.get(name: String(username)) == nil else {
                    ws.write(.text("\(username) is already connected"))
                    ws.close(promise: nil)
                    return
                }
                // add new user
                request.application.connectionMgr.newUser(name: String(username), ws: ws)
            }
        )
        // initialize connection manager
        self.connectionMgr = .init()
    }
}
