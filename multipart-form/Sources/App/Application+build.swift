import Hummingbird
import MultipartKit
import Mustache

protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
}

func buildApplication(_ args: AppArguments) async throws -> some ApplicationProtocol {
    let library = try await MustacheLibrary(directory: "templates")
    assert(library.getTemplate(named: "page") != nil, "Set your working directory to the root folder of this example to get it to work")

    let router = Router(context: MultipartRequestContext.self)
    router.middlewares.add(FileMiddleware())
    WebController(mustacheLibrary: library).addRoutes(to: router)
    return Application(router: router, configuration: .init(address: .hostname(args.hostname, port: args.port)))
}
