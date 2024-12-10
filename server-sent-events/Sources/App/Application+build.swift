import Hummingbird
import Logging
import NIOCore
import SSEKit
import ServiceLifecycle

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
public func buildApplication(
    _ arguments: some AppArguments
) async throws
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
    let requestPublisher = Publisher<String>()
    let router = buildRouter(requestPublisher: requestPublisher)
    let app = Application(
        router: router,
        configuration: .init(
            address: .hostname(arguments.hostname, port: arguments.port),
            serverName: "server_sent_events"
        ),
        services: [requestPublisher],
        logger: logger
    )
    return app
}

/// Build router
func buildRouter(requestPublisher: Publisher<String>) -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    // Add middleware
    router.addMiddleware {
        // logging middleware
        LogRequestsMiddleware(.info)
        PublishRequestsMiddleware(requestPublisher: requestPublisher)
    }
    router.get("events") { request, context -> Response in
        .init(
            status: .ok,
            headers: [.contentType: "text/event-stream"],
            body: .init { writer in
                let allocator = ByteBufferAllocator()
                let (stream, id) = requestPublisher.subscribe()
                try await withGracefulShutdownHandler {
                    // If connection if closed then this function will call the `onInboundCLosed` closure
                    try await request.body.consumeWithInboundCloseHandler { request in
                        for try await value in stream {
                            try await writer.write(
                                ServerSentEvent(data: .init(string: value)).makeBuffer(
                                    allocator: allocator
                                )
                            )
                        }
                    } onInboundClosed: {
                        requestPublisher.unsubscribe(id)
                    }
                } onGracefulShutdown: {
                    requestPublisher.unsubscribe(id)
                }
                try await writer.finish(nil)
            }
        )
    }
    return router
}

/// Middleware to publish requests
struct PublishRequestsMiddleware<Context: RequestContext>: RouterMiddleware {
    let requestPublisher: Publisher<String>
    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        await requestPublisher.publish("\(request.method): \(request.uri.path)")
        return try await next(request, context)
    }
}
