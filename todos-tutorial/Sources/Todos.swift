import ArgumentParser
import Hummingbird


@main
struct Todos: AsyncParsableCommand, AppArguments {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"


    @Option(name: .shortAndLong)
    var port: Int = 8080


    var testing: Bool { false }


    func run() async throws {
        // create application
        let app = try await buildApplication(self)
        // run application
        try await app.runService()
    }
}


/// Arguments extracted from commandline
protocol AppArguments {
    var hostname: String { get}
    var port: Int { get }
    var testing: Bool { get }
}


/// Build a HBApplication
func buildApplication(_ args: some AppArguments) async throws -> some HBApplicationProtocol {
    // create router
    let router = HBRouter(context: TodoRequestContext.self)
    // add logging middleware
    router.middlewares.add(HBLogRequestsMiddleware(.info))
    // add hello route
    router.get("/") { request, context in
        "Hello\n"
    }
    // add Todos API
    TodoController(repository: TodoMemoryRespository()).addRoutes(to: router.group("todos"))
    // create application
    let app = HBApplication(
        router: router,
        configuration: .init(address: .hostname(args.hostname, port: args.port))
    )
    return app
}