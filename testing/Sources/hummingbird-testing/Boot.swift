import Hummingbird

public struct Boot {
    // MARK: - Add Routes here
    public static func configureRoutes(_ app: inout HBApplication) throws {
        app.router.get("/healthcheck") { req in
            "OK"
        }
    }
    
    // MARK: - Application boot
    public static func runApp(hostname: String, port: Int) throws {
        var app = HBApplication(configuration: .init(address: .hostname(hostname, port: port)))
        try Boot.configureRoutes(&app)
        app.start()
        app.wait()
    }
}
