import Hummingbird
import HummingbirdTesting
import Logging
import XCTest

@testable import App

final class AppTests: XCTestCase {
    struct TestArguments: AppArguments {
        let hostname = "127.0.0.1"
        let port = 0
        let logLevel: Logger.Level? = .trace
    }

    func testApp() async throws {
        var environment = Environment()
        environment.set("s3_file_region", value: "us-east-1")
        environment.set("s3_file_bucket", value: "test-bucket")
        let args = TestArguments()
        let app = try await buildApplication(args, environment: environment)
        try await app.test(.router) { client in
            try await client.execute(uri: "/health", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }
}
