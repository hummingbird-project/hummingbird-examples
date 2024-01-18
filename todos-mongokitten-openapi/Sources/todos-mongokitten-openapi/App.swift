import ArgumentParser
import Hummingbird
import OpenAPIHummingbird
import OpenAPIRuntime
import MongoKitten

@main struct HummingbirdArguments: AsyncParsableCommand {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 8080

    @Option(name: .shortAndLong)
    var connectionString: String = "mongodb://localhost:27017/mongo-todos"

    func run() async throws {
        let mongo = try await MongoDatabase.connect(to: connectionString)
        let router = HBRouter()
        router.middlewares.add(HBLogRequestsMiddleware(.info))
        let api = API(mongo: mongo)
        try api.registerHandlers(on: router)
        
        let app = HBApplication(
            router: router,
            configuration: .init(address: .hostname(hostname, port: port))
        )
        try await app.runService()
    }
}