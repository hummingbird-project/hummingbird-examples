import Hummingbird
import HummingbirdFoundation

public protocol AppArguments {
}

extension HBApplication {
    /// configure your application
    /// add middleware
    /// setup the encoder/decoder
    /// add your routes
    func configure(_ args: AppArguments) async throws {
        self.postgresConnectionGroup = .init(
            source: .init(
                configuration: .init(
                    host: "localhost", 
                    port: 5432, 
                    username: "hummingbird", 
                    database: "hummingbird", 
                    password: "hb-password"
                )
            ), 
            maxConnections: 16, 
            eventLoopGroup: self.eventLoopGroup, 
            logger: self.logger
        )

        try await setupDatabase()

        // set encoder and decoder
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        // middleware
        self.middleware.add(HBLogRequestsMiddleware(.debug))
        self.middleware.add(HBCORSMiddleware(
            allowOrigin: .originBased,
            allowHeaders: ["Content-Type"],
            allowMethods: [.GET, .OPTIONS, .POST, .DELETE, .PATCH]
        ))

        self.router.get("/") { _ in
            return "Hello"
        }
        let todoController = TodoController(connectionPoolGroup: self.postgresConnectionGroup)
        todoController.addRoutes(to: self.router.group("todos"))
    }
}

extension HBApplication {
    var postgresConnectionGroup: HBConnectionPoolGroup<PostgresConnectionSource> {
        get { self.extensions.get(\.postgresConnectionGroup) }
        set { self.extensions.set(\.postgresConnectionGroup, value: newValue) }
    }
}