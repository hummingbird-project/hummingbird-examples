@testable import App
import Hummingbird
import HummingbirdXCT
import XCTest

final class AppTests: XCTestCase {
    struct TestArguments: AppArguments {}

    func testApp() throws {
        let args = TestArguments()
        let app = HBApplication(testing: .live)
        try app.configure(args)

        try app.XCTStart()
        defer { XCTAssertNoThrow(app.XCTStop()) }

        try app.XCTExecute(uri: "/health", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
        }
    }
}
