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
        // We decode both JSON and URLEncoded forms so need a custom decoder
        self.decoder = RequestDecoder()
        // add logging middleware
        self.middleware.add(HBLogRequestsMiddleware(.info))
        // add file middleware to server css and js files
        self.middleware.add(HBFileMiddleware(application: self))
        self.middleware.add(HBCORSMiddleware(
            allowOrigin: .originBased,
            allowHeaders: ["Content-Type"],
            allowMethods: [.GET, .OPTIONS, .POST, .DELETE, .PATCH]
        ))

        // add Fluent
        self.addFluent()

        // add support for sessions using a fluent database. This needs to be added
        // before the migrate
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

        // add health check route
        self.router.get("/health") { _ in
            return HTTPResponseStatus.ok
        }

        // load mustache template library
        let library = try HBMustacheLibrary(directory: "templates")
        assert(library.getTemplate(named: "head") != nil, "Set your working directory to the root folder of this example to get it to work")

        // Add routes serving HTML files
        WebController(mustacheLibrary: library).addRoutes(to: self.router)
        // Add api routes managing todos
        TodoController().addRoutes(to: self.router.group("api/todos"))
        // Add api routes managing users
        UserController().addRoutes(to: self.router.group("api/users"))
    }
}
