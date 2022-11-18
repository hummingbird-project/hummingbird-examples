import FluentSQLiteDriver
import Hummingbird
import HummingbirdFluent
import HummingbirdFoundation

extension HBApplication {
    /// configure your application
    /// add middleware
    /// setup the encoder/decoder
    /// add your routes 
    public func configure() throws {
        // add JSON encoder/decoder as we are reading and writing JSON
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()

        // add Fluent
        self.addFluent()
        // add sqlite database
        self.fluent.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
        // add session management using fluent
        self.addSessions(using: .fluent)
        // add migrations
        self.fluent.migrations.add(CreateUser())

        // add logging middleware
        self.middleware.add(HBLogRequestsMiddleware(.debug))

        // routes
        self.router.get("/") { _ in
            return "Hello"
        }

        let userController = UserController()
        userController.addRoutes(to: self.router.group("user"))
    }
}
