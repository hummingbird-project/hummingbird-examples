import App
import Hummingbird
import HummingbirdXCT
import XCTest

final class AppTests: XCTestCase {
    struct TestArguments: AppArguments {
        let processJobs: Bool
    }
    func testApp() throws {
        let app = HBApplication(testing: .live)
        try app.configure(TestArguments(processJobs: true))

        try app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.body.map { String(buffer: $0) }, "Hello")
        }
    }
}
