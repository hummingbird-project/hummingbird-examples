import Foundation
import Hummingbird
import HummingbirdFoundation
import SotoS3

/// Application arguments protocol. We use a protocol so we can call
/// `HBApplication.configure` inside Tests as well as in the App executable.
/// Any variables added here also have to be added to `App` in App.swift and
/// `TestArguments` in AppTest.swift
public protocol AppArguments {}

extension HBApplication {
    /// configure your application
    /// add middleware
    /// setup the encoder/decoder
    /// add your routes
    func configure(_: AppArguments) throws {
        let env = HBEnvironment()
        guard let bucket = env.get("s3_upload_bucket") else {
            preconditionFailure("Requires \"s3_upload_bucket\" environment variable")
        }

        self.encoder = JSONEncoder()
        self.middleware.add(HBLogRequestsMiddleware(.info))
        self.aws.client = AWSClient(httpClientProvider: .createNewWithEventLoopGroup(self.eventLoopGroup))
        let s3 = S3(client: self.aws.client, region: .euwest1)

        let fileController = S3FileController(
            s3: s3,
            bucket: bucket,
            folder: env.get("s3_upload_folder") ?? "hb-upload-s3"
        )
        fileController.addRoutes(to: self.router.group("files"))

        self.router.get("/health") { _ -> HTTPResponseStatus in
            return .ok
        }
    }
}
