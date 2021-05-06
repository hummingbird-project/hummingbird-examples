import FluentSQLiteDriver
import Hummingbird
import HummingbirdFluent
import HummingbirdFoundation

public protocol AppArguments {
    var inMemoryDatabase: Bool { get }
    var migrate: Bool { get }
}

extension HBApplication {
    /// configure your application
    /// add middleware
    /// setup the encoder/decoder
    /// add your routes
    public func configure(_ arguments: AppArguments) throws {
        // add JSON encoder/decoder as we are reading and writing JSON
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()

        // add Fluent
        self.addFluent()
        // add sqlite database
        if arguments.inMemoryDatabase {
            self.fluent.databases.use(.sqlite(.memory), as: .sqlite)
        } else {
            self.fluent.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
        }
        // add migrations
        self.fluent.migrations.add(CreateUser())
        self.fluent.migrations.add(CreateSession())
        // migrate
        if arguments.migrate || arguments.inMemoryDatabase == true {
            try self.fluent.migrate().wait()
        }

        // add scheduled task
        SessionAuthenticator.scheduleTidyUp(application: self)

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
