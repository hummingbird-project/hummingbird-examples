@testable import App
import Hummingbird
import HummingbirdXCT
import XCTest

final class AppTests: XCTestCase {
    func testApp() async throws {
        let app = try await buildApplication(configuration: .init())

        try await app.test(.router) { client in
            let urlencoded = "name=Adam&age=34"
            try await client.XCTExecute(
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
