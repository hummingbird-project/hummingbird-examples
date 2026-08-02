import Configuration
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
public func buildApplication(reader: ConfigReader) async throws -> some ApplicationProtocol {
    let logger = {
        var logger = Logger(label: "s3_file_provider")
        logger.logLevel = reader.string(forKey: "log.level", as: Logger.Level.self, default: .info)
        return logger
    }()

    let awsClient = AWSClient()
    do {
        let router = try buildRouter(reader: reader, awsClient: awsClient)
        let app = Application(
            router: router,
            configuration: .init(reader: reader),
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
    reader: ConfigReader,
    awsClient: AWSClient
) throws -> Router<AppRequestContext> {
    let region = try reader.requiredString(forKey: "s3.file.region", as: Region.self)
    let bucket = try reader.requiredString(forKey: "s3.file.bucket")
    let rootFolder = reader.string(forKey: "s3.file.path", default: "")

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
