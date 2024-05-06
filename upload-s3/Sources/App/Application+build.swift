import Foundation
import Hummingbird
import Logging
import ServiceLifecycle
import SotoS3

/// Application arguments protocol. We use a protocol so we can call
/// `HBApplication.configure` inside Tests as well as in the App executable.
/// Any variables added here also have to be added to `App` in App.swift and
/// `TestArguments` in AppTest.swift
public protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var logLevel: Logger.Level? { get }
}

struct AWSClientService: Service {
    let client: AWSClient

    func run() async throws {
        // Ignore cancellation error
        try? await gracefulShutdown()
        try await self.client.shutdown()
    }
}

func buildApplication(_ args: some AppArguments) -> some ApplicationProtocol {
    let logger = {
        var logger = Logger(label: "html-form")
        logger.logLevel = args.logLevel ?? .info
        return logger
    }()
    let env = Environment()
    guard let bucket = env.get("s3_upload_bucket") else {
        preconditionFailure("Requires \"s3_upload_bucket\" environment variable")
    }

    let awsClient = AWSClient()
    let s3 = S3(client: awsClient, region: .euwest1)

    let router = Router()
    router.middlewares.add(LogRequestsMiddleware(.info))

    router.addRoutes(
        S3FileController(
            s3: s3,
            bucket: bucket,
            folder: env.get("s3_upload_folder") ?? "hb-upload-s3"
        ).getRoutes(),
        atPath: "files"
    )
    router.get("/health") { request, context in
        return HTTPResponse.Status.ok
    }
    var app = Application(
        router: router,
        configuration: .init(address: .hostname(args.hostname, port: args.port)),
        logger: logger
    )
    app.addServices(AWSClientService(client: awsClient))
    return app
}
