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
            arguments.logLevel ??
            environment.get("LOG_LEVEL").flatMap(Logger.Level.init) ?? .info
        return logger
    }()

    let awsClient = AWSClient()
    let router = buildRouter(environment, awsClient: awsClient)
    let app = Application(
        router: router,
        configuration: .init(
            address: .hostname(arguments.hostname, port: arguments.port),
            serverName: "s3_file_provider"
        ),
        services: [AWSClientService(client: awsClient)],
        logger: logger
    )
    return app
}

/// Build router
func buildRouter(
    _ environment: Environment,
    awsClient: AWSClient
) -> Router<AppRequestContext> {
    guard let regionString = environment.get("s3_file_region") else {
        preconditionFailure("Requires \"s3_file_region\" environment variable")
    }
    let region = Region(rawValue: regionString)
    guard let bucket = environment.get("s3_file_bucket") else {
        preconditionFailure("Requires \"s3_file_bucket\" environment variable")
    }
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
    router.get("/health") { _,_ -> HTTPResponse.Status in
        return .ok
    }
    return router
}