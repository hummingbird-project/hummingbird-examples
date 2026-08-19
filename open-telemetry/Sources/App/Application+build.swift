import AsyncAlgorithms
public import Hummingbird
public import Logging
import MQTTNIO
import Metrics
import NIOCore
import OTel
import SSEKit
import ServiceLifecycle
import Tracing

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
    let channel: any Channel

    init(source: Source) {
        self.coreContext = .init(source: source)
        self.channel = source.channel
    }
}

// By conforming to the RequestContext to RemoteAddressRequestContext the TracingMiddleware
// can extract the values for `net.sock.peer.addr` and `net.sock.peer.port`
extension AppRequestContext: RemoteAddressRequestContext {
    var remoteAddress: NIOCore.SocketAddress? { self.channel.remoteAddress }
}

///  Build application
/// - Parameter arguments: application arguments
public func buildApplication(_ arguments: some AppArguments) async throws -> some ApplicationProtocol {
    let environment = Environment()
    let logLevel = arguments.logLevel ?? environment.get("LOG_LEVEL").flatMap { Logger.Level(rawValue: $0) } ?? .debug
    LoggingSystem.bootstrap { label in
        var handler = StreamLogHandler.standardOutput(label: label, metadataProvider: OTel.makeLoggingMetadataProvider())
        handler.logLevel = logLevel
        return handler
    }

    var otelConfig = OTel.Configuration.default
    otelConfig.serviceName = "Hummingbird"
    otelConfig.logs.enabled = false
    // To use GRPC you can set the otlpExporter protocol for each exporter
    //otelConfig.metrics.otlpExporter.protocol = .grpc
    //otelConfig.traces.otlpExporter.protocol = .grpc
    let observability = try OTel.bootstrap(configuration: otelConfig)

    var logger = Logger(label: "open-telemetry")
    logger.logLevel = arguments.logLevel ?? environment.get("LOG_LEVEL").flatMap { Logger.Level($0) } ?? .debug

    let router = buildRouter()
    let app = Application(
        router: router,
        configuration: .init(
            address: .hostname(arguments.hostname, port: arguments.port),
            serverName: "open-telemetry-server"
        ),
        services: [observability],
        logger: logger
    )
    return app
}

/// Build router
func buildRouter() -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    // Add middleware
    router.addMiddleware {
        // metrics middleware
        MetricsMiddleware()
        // tracing middleware
        TracingMiddleware()
        // logging middleware
        LogRequestsMiddleware(.debug)
    }
    // Add default endpoint
    router.get("/") { _, _ in
        "Hello!"
    }
    // Add test parameter endpoint
    router.get("/test/{param}") { _, context in
        let param = try context.parameters.require("param")
        return "Testing \(param)!"
    }
    // Add wait endpoint
    router.post("/wait") { request, _ in
        let time = try request.uri.queryParameters.require("time", as: Double.self)
        // Add child span
        try await withSpan("sleep") { span in
            span.attributes["wait.time"] = time
            try await Task.sleep(for: .seconds(time))
        }
        return HTTPResponse.Status.ok
    }
    // Add MQTT publish
    router.post("/publish/{topic}") { request, context in
        let topic = try context.parameters.require("topic")
        let body = try await request.body.collect(upTo: .max)
        try await MQTTConnection.withConnection(address: .hostname("127.0.0.1"), configuration: .init(versionConfiguration: .v5_0())) { connection in
            _ = try await connection.v5.publish(to: "otel/\(topic)", payload: body, qos: .atLeastOnce, retain: false)
        }
        return HTTPResponse.Status.ok
    }
    // Add MQTT publish
    router.get("/subscribe/{filter}") { request, context in
        let filter = try context.parameters.require("filter")
        // Returns a Response that streams events to the client
        return Response(
            status: .ok,
            headers: [.contentType: "text/event-stream"],
            body: .init { writer in
                // This body is an unbounded stream of data
                // It will stay open until the client closes the connection, or the stream ends
                let allocator = ByteBufferAllocator()

                // We create a stream to pass our cancel event to
                enum StreamResult: Sendable {
                    case event(MQTTPublishInfo)
                    case cancel
                }
                let (cancelStream, cancelCont) = AsyncStream.makeStream(of: StreamResult.self)

                // This is a helper that will call the `onGracefulShutdown` closure
                // when the application is shutting down.
                // This helps ensure that the application will gracefully shut down, meaning
                // any existing work will be correctly cleaned up before the application exits.
                let uncheckedWriter = UncheckedSendableWriter(writer)
                try await withGracefulShutdownHandler {
                    // If connection if closed then this function will call the `onInboundClosed` closure
                    try await request.body.consumeWithInboundCloseHandler { requestBody in
                        try await MQTTConnection.withConnection(
                            address: .hostname("127.0.0.1"),
                            configuration: .init(versionConfiguration: .v5_0())
                        ) { connection in

                            try await connection.subscribe(to: [.init(topicFilter: "otel/\(filter)", qos: .atLeastOnce)]) { subscription in
                                let publishAndCancelStream = merge(cancelStream, subscription.map { .event($0) })
                                outsideLoop: for try await value in publishAndCancelStream {
                                    // A new value was received from the data source
                                    switch value {
                                    case .event(let publishInfo):
                                        try await connection.withMessageSpan(publishInfo) { _ in
                                            try await writer.write(
                                                ServerSentEvent(data: .init(string: .init(buffer: publishInfo.payload))).makeBuffer(
                                                    allocator: allocator
                                                )
                                            )
                                        }
                                    case .cancel:
                                        // if it is a cancellation event then we exit the loop
                                        break outsideLoop
                                    }
                                }
                            }
                        }
                    } onInboundClosed: {
                        cancelCont.yield(.cancel)
                    }
                } onGracefulShutdown: {
                    cancelCont.yield(.cancel)
                }
                try await uncheckedWriter.writer.finish(nil)
            }
        )
    }
    return router
}

final class UncheckedSendableWriter: @unchecked Sendable {
    var writer: (any ResponseBodyWriter)

    init(_ writer: (any ResponseBodyWriter)) {
        self.writer = writer
    }
}
