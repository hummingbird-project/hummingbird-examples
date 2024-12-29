import Hummingbird
import Instrumentation
import Logging
import Metrics
import OTLPGRPC
import OTel
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
typealias AppRequestContext = BasicRequestContext

///  Build application
/// - Parameter arguments: application arguments
public func buildApplication(_ arguments: some AppArguments) async throws -> some ApplicationProtocol {
    let environment = Environment()
    let logger = {
        var logger = Logger(label: "open-telemetry")
        logger.logLevel =
            arguments.logLevel ?? environment.get("LOG_LEVEL").flatMap { Logger.Level(rawValue: $0) } ?? .info
        return logger
    }()

    let otel = try await setupOTEL()

    let router = buildRouter()
    var app = Application(
        router: router,
        configuration: .init(
            address: .hostname(arguments.hostname, port: arguments.port),
            serverName: "open-telemetry-server"
        ),
        logger: logger
    )
    app.addServices(otel.metrics, otel.tracer)
    return app
}

func setupOTEL() async throws -> (metrics: Service, tracer: Service) {
    // Bootstrap the logging backend with the OTel metadata provider which includes span IDs in logging messages.
    LoggingSystem.bootstrap { label in
        var handler = StreamLogHandler.standardError(label: label, metadataProvider: .otel)
        handler.logLevel = .trace
        return handler
    }
    // Configure OTel resource detection to automatically apply helpful attributes to events.
    let environment = OTelEnvironment.detected()
    let resourceDetection = OTelResourceDetection(detectors: [
        OTelProcessResourceDetector(),
        OTelEnvironmentResourceDetector(environment: environment),
        .manual(OTelResource(attributes: ["service.name": "hummingbird_server"])),
    ])
    let resource = await resourceDetection.resource(environment: environment, logLevel: .trace)

    // Bootstrap the metrics backend to export metrics periodically in OTLP/gRPC.
    let registry = OTelMetricRegistry()
    let metricsExporter = try OTLPGRPCMetricExporter(configuration: .init(environment: environment))
    let metrics = OTelPeriodicExportingMetricsReader(
        resource: resource,
        producer: registry,
        exporter: metricsExporter,
        configuration: .init(
            environment: environment,
            exportInterval: .seconds(5)  // NOTE: This is overridden for the example; the default is 60 seconds.
        )
    )
    MetricsSystem.bootstrap(OTLPMetricsFactory(registry: registry))

    // Bootstrap the tracing backend to export traces periodically in OTLP/gRPC.
    let exporter = try OTLPGRPCSpanExporter(configuration: .init(environment: environment))
    let processor = OTelBatchSpanProcessor(exporter: exporter, configuration: .init(environment: environment))
    let tracer = OTelTracer(
        idGenerator: OTelRandomIDGenerator(),
        sampler: OTelConstantSampler(isOn: true),
        propagator: OTelW3CPropagator(),
        processor: processor,
        environment: environment,
        resource: resource
    )
    InstrumentationSystem.bootstrap(tracer)
    return (metrics: metrics, tracer: tracer)
}

/// Build router
func buildRouter() -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    // Add middleware
    router.addMiddleware {
        // logging middleware
        LogRequestsMiddleware(.info)
        // metrics middleware
        MetricsMiddleware()
        // tracing middleware
        TracingMiddleware()
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
        try await Task.sleep(for: .seconds(time))
        return HTTPResponse.Status.ok
    }
    return router
}
