import Configuration
import Hummingbird
import HummingbirdTesting
import Logging
import XCTest

@testable import App

private let reader = ConfigReader(providers: [
    InMemoryProvider(values: [
        "host": "127.0.0.1",
        "port": "0",
        "log.level": "trace",
        "s3.file.region": "us-east-1",
        "s3.file.bucket": "test-bucket",
    ])
])

final class AppTests: XCTestCase {
    func testApp() async throws {
        let app = try await buildApplication(reader: reader)
        try await app.test(.router) { client in
            try await client.execute(uri: "/health", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }
}
