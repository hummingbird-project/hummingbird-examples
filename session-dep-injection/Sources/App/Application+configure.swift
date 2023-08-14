import FluentSQLiteDriver
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent
import HummingbirdFoundation

protocol AppArguments {
    var migrate: Bool { get }
    var inMemoryDatabase: Bool { get }
}

extension HBApplication {
    /// configure your application
    /// add middleware
    /// setup the encoder/decoder
    /// add your routes 
    func configure(_ arguments: AppArguments) throws {
        // add JSON encoder/decoder as we are reading and writing JSON
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()

        // Fluent
        let fluent = HBFluent(
            eventLoopGroup: self.eventLoopGroup, 
            threadPool: self.threadPool, 
            logger: self.logger
        )
        // add sqlite database
        fluent.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)

        // Sessions
        let persist = HBFluentPersistDriver(fluent: fluent)
        let sessionStorage = HBSessionStorage(persist)

        // add migrations
        fluent.migrations.add(CreateUser())

        if arguments.migrate || arguments.inMemoryDatabase {
            try fluent.migrate().wait()
        }

        // add logging middleware
        self.middleware.add(HBLogRequestsMiddleware(.debug))

        // routes
        self.router.get("/") { _ in
            return "Hello"
        }

        // shutdown persist and fluent when the app closes
        self.lifecycle.registerShutdown(label: "app", .sync {
            persist.shutdown()
            fluent.shutdown()
        })

        let userController = UserController(fluent: fluent, sessionStorage: sessionStorage)
        userController.addRoutes(to: self.router.group("user"))
    }
}
