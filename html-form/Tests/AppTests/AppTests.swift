@testable import App
import Hummingbird
import HummingbirdTesting
import Logging
import XCTest

final class AppTests: XCTestCase {
    struct TestArguments: AppArguments {
        var hostname: String = "127.0.0.1"
        var port = 8080
        var logLevel: Logger.Level? = .trace
    }

    func testApp() async throws {
        let app = try await buildApplication(args: TestArguments())

        try await app.test(.router) { client in
            let urlencoded = "name=Adam&age=34"
            try await client.execute(
                uri: "/",
                method: .post,
                headers: [.contentType: "application/x-www-form-urlencoded"],
                body: ByteBufferAllocator().buffer(string: urlencoded)
            ) { response in
                XCTAssertEqual(response.headers[.contentType], "text/html")
                XCTAssertEqual(response.status, .ok)
            }
        }
    }
}
