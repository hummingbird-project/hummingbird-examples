@testable import App
import Hummingbird
import HummingbirdXCT
import XCTest

final class AppTests: XCTestCase {
    func testApp() async throws {
        let app = buildApplication(configuration: .init())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(String(buffer: response.body), "Hello")
            }
        }
    }
}
