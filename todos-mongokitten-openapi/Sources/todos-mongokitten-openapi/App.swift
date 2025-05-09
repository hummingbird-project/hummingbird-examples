import ArgumentParser
import Hummingbird
import MongoKitten
import OpenAPIHummingbird
import OpenAPIRuntime

@main
struct HummingbirdArguments: AsyncParsableCommand {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 8080

    /// The MongoDB connection string to use to connect to the database
    /// The following command can get you started with a local MongoDB instance:
    ///
    ///     docker run -d -p 27017:27017 mongo
    /// 
    /// The `/mongo-todos` is the name of the database we will use.
    /// A MongoDB instance can host many "databases", usually one per application.
    @Option(name: .shortAndLong)
    var connectionString: String = "mongodb://localhost:27017/mongo-todos"

    func run() async throws {
        // Connect to MongoDB through MongoKitten
        let mongo = try await MongoDatabase.connect(to: self.connectionString)

        // Create a router
        let router = Router()
        // Add a middleware to log requests
        router.add(middleware: LogRequestsMiddleware(.info))

        // Create an OpenAPI instance, which will handle the API requests
        // The OpenAPI generator ensures that the API is fully implemented and conforms
        // to the OpenAPI specification
        let api = API(mongo: mongo)
        
        // Register the API handlers on the router
        try api.registerHandlers(on: router)

        let app = Application(
            router: router,
            configuration: .init(address: .hostname(hostname, port: port))
        )
        try await app.runService()
    }
}
