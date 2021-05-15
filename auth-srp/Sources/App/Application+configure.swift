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
        self.middleware.add(HBFileMiddleware(application: self))
        self.middleware.add(HBLogRequestsMiddleware(.info, includeHeaders: true))
        self.addFluent()
        // add sqlite database
        if arguments.inMemoryDatabase {
            self.fluent.databases.use(.sqlite(.memory), as: .sqlite)
        } else {
            self.fluent.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
        }
        // add migrations
        self.fluent.migrations.add(CreateUser())

        // add persist, must be done before migrate is called if fluent is used
        self.addPersist(using: .fluent)

        // migrate
        if arguments.migrate || arguments.inMemoryDatabase == true {
            try self.fluent.migrate().wait()
        }

        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()

        UserController().addRoutes(to: self.router.group("/api/user"))
    }
}
