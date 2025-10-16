import Hummingbird
import Logging
import SotoCore
import SotoS3

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
public func buildApplication(_ arguments: some AppArguments, environment: Environment) async throws -> some ApplicationProtocol {
    let logger = {
        var logger = Logger(label: "s3_file_provider")
        logger.logLevel =
            arguments.logLevel ?? environment.get("LOG_LEVEL").flatMap(Logger.Level.init) ?? .info
        return logger
    }()

    let awsClient = AWSClient()
    do {
        let router = try buildRouter(environment, awsClient: awsClient)
        let app = Application(
            router: router,
            configuration: .init(
                address: .hostname(arguments.hostname, port: arguments.port),
                serverName: "s3_file_provider"
            ),
            services: [awsClient],
            logger: logger
        )
        return app
    } catch {
        try await awsClient.shutdown()
        throw error
    }
}

/// Build router
func buildRouter(
    _ environment: Environment,
    awsClient: AWSClient
) throws -> Router<AppRequestContext> {
    let regionString = try environment.require("s3_file_region")
    let region = Region(rawValue: regionString)
    let bucket = try environment.require("s3_file_bucket")
    let rootFolder = environment.get("s3_file_path") ?? ""

    let router = Router(context: AppRequestContext.self)
    // Add middleware
    router.addMiddleware {
        // logging middleware
        LogRequestsMiddleware(.info)
        // File middleware
        FileMiddleware(
            fileProvider: CachingFileProvider(
                S3FileProvider(
                    bucket: bucket,
                    rootFolder: rootFolder,
                    s3: S3(client: awsClient, region: region)
                )
            )
        )
    }
    // Add health endpoint
    router.get("/health") { _, _ -> HTTPResponse.Status in
        .ok
    }
    return router
}
