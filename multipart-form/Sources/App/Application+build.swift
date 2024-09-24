import Foundation
import Hummingbird
import MultipartKit
import Mustache

protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
}

func buildApplication(_ args: AppArguments) async throws -> some ApplicationProtocol {
    // Verify the working directory is correct
    assert(FileManager.default.fileExists(atPath: "public/images/hummingbird.png"), "Set your working directory to the root folder of this example to get it to work")
    // load mustache template library
    let library = try await MustacheLibrary(directory: Bundle.module.resourcePath!)

    let router = Router(context: MultipartRequestContext.self)
    router.add(middleware: FileMiddleware())
    WebController(mustacheLibrary: library).addRoutes(to: router)
    return Application(router: router, configuration: .init(address: .hostname(args.hostname, port: args.port)))
}
