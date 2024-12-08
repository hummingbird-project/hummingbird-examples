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
    }
    // Add health endpoint
    router.get("/health") { _, _ -> HTTPResponse.Status in
        .ok
    }
    router.get("events") { request, context -> Response in
        .init(
            status: .ok,
            headers: [.contentType: "text/event-stream"],
            body: .init { writer in
                let allocator = ByteBufferAllocator()
                let (stream, id) = requestPublisher.addSubsciber()
                var unsafeWriter = UnsafeTransfer(writer)
                try await request.body.consumeWithInboundCloseHandler { request in
                    for try await value in stream {
                        try await unsafeWriter.wrappedValue.write(
                            ServerSentEvent(data: .init(string: value)).makeBuffer(
                                allocator: allocator
                            )
                        )
                    }
                } onInboundClosed: {
                    requestPublisher.removeSubsciber(id)
                }
                try await writer.finish(nil)
            }
        )
    }
    router.get("**") { request, _ -> HTTPResponse.Status in
        await requestPublisher.publish("\(request.method): \(request.uri.path)")
        return .ok
    }
    return router
}

@usableFromInline
package struct UnsafeTransfer<Wrapped> {
    @usableFromInline
    package var wrappedValue: Wrapped

    @inlinable
    package init(_ wrappedValue: Wrapped) {
        self.wrappedValue = wrappedValue
    }
}

extension UnsafeTransfer: @unchecked Sendable {}
