import Hummingbird
import Logging
import Metrics
import NIOCore
import OTel
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
    let channel: Channel

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
    logger.logLevel = arguments.logLevel ?? environment.get("LOG_LEVEL").flatMap { Logger.Level(rawValue: $0) } ?? .debug

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
    return router
}
