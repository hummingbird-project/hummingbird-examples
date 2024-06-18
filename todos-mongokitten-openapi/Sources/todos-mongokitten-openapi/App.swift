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
    @Option(name: .shortAndLong)
    var connectionString: String = "mongodb://localhost:27017/mongo-todos"

    func run() async throws {
        // Connect to MongoDB
        let mongo = try await MongoDatabase.connect(to: self.connectionString)

        let router = Router()
        router.add(middleware: LogRequestsMiddleware(.info))
        let api = API(mongo: mongo)
        try api.registerHandlers(on: router)

        let app = Application(
            router: router,
            configuration: .init(address: .hostname(hostname, port: port))
        )
        try await app.runService()
    }
}
