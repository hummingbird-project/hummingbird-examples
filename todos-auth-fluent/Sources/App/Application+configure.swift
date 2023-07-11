import FluentSQLiteDriver
import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent
import HummingbirdFoundation
import HummingbirdMustache

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
        self.logger.logLevel = .info
        // set encoder and decoder
        self.encoder = JSONEncoder()
        self.decoder = RequestDecoder()
        // middleware
        self.middleware.add(HBLogRequestsMiddleware(.debug))
        self.middleware.add(HBFileMiddleware(application: self))
        self.middleware.add(HBCORSMiddleware(
            allowOrigin: .originBased,
            allowHeaders: ["Content-Type"],
            allowMethods: [.GET, .OPTIONS, .POST, .DELETE, .PATCH]
        ))

        // add Fluent
        self.addFluent()

        self.addSessions(using: .fluent)

        // add sqlite database
        if arguments.inMemoryDatabase {
            self.fluent.databases.use(.sqlite(.memory), as: .sqlite)
        } else {
            self.fluent.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
        }
        // add migrations
        self.fluent.migrations.add(CreateTodo())
        self.fluent.migrations.add(CreateUser())
        // migrate
        if arguments.migrate || arguments.inMemoryDatabase {
            try self.fluent.migrate().wait()
        }

        self.router.get("/health") { _ in
            return "Hello"
        }

        // load mustache template library
        let library = try HBMustacheLibrary(directory: "templates")
        assert(library.getTemplate(named: "head") != nil, "Set your working directory to the root folder of this example to get it to work")

        WebController(mustacheLibrary: library).addRoutes(to: self.router)
        TodoController().addRoutes(to: self.router.group("todos"))
        UserController().addRoutes(to: self.router.group("users"))
    }
}
