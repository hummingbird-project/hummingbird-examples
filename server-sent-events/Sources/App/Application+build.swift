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

/// A custom request context used by application
/// The request context can store any data that is associated with the request
/// This could include things like the authenticated user, a JWT token, or other information derived
/// from the request such as their IP address, or user agent.
/// 
/// The Request Context can be accessed and modified by any middleware or route handler.
/// This allows middleware to pass information forward to the next middleware or route handler in the chain.
struct AppRequestContext: RequestContext {
    /// The Core Context Storage is used to store any data that _hummingbird_ needs to know about the request
    /// This is the only mandatory property that MUST be set by the developer
    var coreContext: CoreRequestContextStorage

    /// This is the Channel (e.g. Socket) that sent the request
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

    // GET /events
    router.get("events") { request, context -> Response in
        // Returns a Response that streams events to the client
        Response(
            status: .ok,
            headers: [.contentType: "text/event-stream"],
            body: .init { writer in
                // This body is an unbounded stream of data
                // It will stay open until the client closes the connection, or the stream ends
                let allocator = ByteBufferAllocator()

                // A subscription to some data source is opened
                // This might be a database like Redis, or some other data source
                let (stream, id) = requestPublisher.subscribe()

                // This is a helper that will call the `onGracefulShutdown` closure
                // when the application is shutting down.
                // This helps ensure that the application will gracefully shut down, meaning
                // any existing work will be correctly cleaned up before the application exits.
                try await withGracefulShutdownHandler {
                    // If connection if closed then this function will call the `onInboundCLosed` closure
                    try await request.body.consumeWithInboundCloseHandler { requestBody in
                        // This loop will suspend until a new message is available, or the stream ends
                        // If the stream ends, the loop will finish exiting the loop.
                        for try await value in stream {
                            // A new value was received from the data source
                            // We create a new ServerSentEvent with the value and write it to the response body
                            // The `await` before the `write` is used to ensure that the write is completed
                            // before the loop continues to await the next value
                            // This applies backpressure to the data source
                            // Depending on the implementation, the data source could buffer the messages
                            // in memory or suspend the production of events until the client is ready to receive them
                            // Additionally, data could be dropped if the client is unable to keep up with the rate of data production
                            try await writer.write(
                                ServerSentEvent(data: .init(string: value)).makeBuffer(
                                    allocator: allocator
                                )
                            )
                        }
                    } onInboundClosed: {
                        // If the client closes the connection, we unsubscribe from the data source 
                        requestPublisher.unsubscribe(id)
                    }
                } onGracefulShutdown: {
                    // If the application is shutting down, we unsubscribe from the data source
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
