import Hummingbird
import Logging

/// Application arguments protocol. We use a protocol so we can call
/// `buildApplication` inside Tests as well as in the App executable.
/// Any variables added here also have to be added to `App` in App.swift and
/// `TestArguments` in AppTest.swift
public protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var logLevel: Logger.Level? { get }
}

public func buildApplication(_ arguments: some AppArguments) async throws -> some ApplicationProtocol {
    let environment = Environment()
    let logger = {
        var logger = Logger(label: "ResponseBodyProcessing")
        logger.logLevel =
            arguments.logLevel ??
            environment.get("LOG_LEVEL").map { Logger.Level(rawValue: $0) ?? .info } ??
            .info
        return logger
    }()
    let router = Router()
    // Add logging
    router.add(middleware: LogRequestsMiddleware(.info))
    // Add logging
    router.add(middleware: AddSHA256DigestMiddleware())
    // Add echo route
    router.post("/echo") { request, context -> Response in
        return Response(
            status: .ok,
            headers: [.contentType: request.headers[.contentType] ?? "application/octet-stream"],
            body: .init(asyncSequence: request.body)
        )
    }
    let app = Application(
        router: router,
        configuration: .init(
            address: .hostname(arguments.hostname, port: arguments.port),
            serverName: "ResponseBodyProcessing"
        ),
        logger: logger
    )
    return app
}
