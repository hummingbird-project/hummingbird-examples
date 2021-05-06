import FluentSQLiteDriver
import Foundation
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

        // add Fluent
        self.addFluent()
        // add sqlite database
        if arguments.inMemoryDatabase {
            self.fluent.databases.use(.sqlite(.memory), as: .sqlite)
        } else {
            self.fluent.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
        }
        // add migrations
        self.fluent.migrations.add(CreateTodo())
        // migrate
        if arguments.migrate || arguments.inMemoryDatabase {
            try self.fluent.migrate().wait()
        }

        self.router.get("/") { _ in
            return "Hello"
        }
        let todoController = TodoController()
        todoController.addRoutes(to: self.router.group("todos"))
    }
}
