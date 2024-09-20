import Hummingbird
import Logging
import NIOCore
import SSEKit

/// Application arguments protocol. We use a protocol so we can call
/// `buildApplication` inside Tests as well as in the App executable.
/// Any variables added here also have to be added to `App` in App.swift and
/// `TestArguments` in AppTest.swift
public protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var logLevel: Logger.Level? { get }
}

// Request context used by application
struct AppRequestContext: RequestContext {
    var coreContext: CoreRequestContextStorage
    let channel: Channel

    init(source: Source) {
        self.coreContext = .init(source: source)
        self.channel = source.channel
    }
}

///  Build application
/// - Parameter arguments: application arguments
public func buildApplication(_ arguments: some AppArguments) async throws
    -> some ApplicationProtocol
{
    let environment = Environment()
    let logger = {
        var logger = Logger(label: "server_side_events")
        logger.logLevel =
            arguments.logLevel ?? environment.get("LOG_LEVEL").map {
                Logger.Level(rawValue: $0) ?? .info
            } ?? .info
        return logger
    }()
    let router = buildRouter()
    let app = Application(
        router: router,
        configuration: .init(
            address: .hostname(arguments.hostname, port: arguments.port),
            serverName: "server_sent_events"
        ),
        logger: logger
    )
    return app
}

/// Build router
func buildRouter() -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    // Add middleware
    router.addMiddleware {
        // logging middleware
        LogRequestsMiddleware(.info)
    }
    // Add health endpoint
    router.get("/health") { _, _ -> HTTPResponse.Status in
        return .ok
    }
    router.get("events") { _, context -> Response in
        return .init(
            status: .ok, headers: [.contentType: "text/event-stream"],
            body: .init { writer in
                let allocator = ByteBufferAllocator()
                for value in 0..<250 {
                    try await Task.sleep(for: .seconds(10))
                    try await writer.write(
                        ServerSentEvent(data: .init(string: value.description)).makeBuffer(
                            allocator: allocator))
                }
                try await writer.finish(nil)
            }
        )
    }
    return router
}
