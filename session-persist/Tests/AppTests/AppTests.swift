@testable import App
import Hummingbird
import HummingbirdXCT
import XCTest

final class AppTests: XCTestCase {
    func testApp() throws {
        let app = HBApplication(testing: .live)
        try app.configure()

        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/health", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
        }
    }
}
