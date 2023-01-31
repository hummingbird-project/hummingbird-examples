import Hummingbird
import HummingbirdFoundation

extension HBApplication {
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
}
