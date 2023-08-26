@testable import App
import Hummingbird
import HummingbirdXCT
import XCTest

struct TestArguments: AppArguments {
    var migrate: Bool = true
    var inMemoryDatabase: Bool = true
}

final class AppTests: XCTestCase {
    func testApp() throws {
        let app = HBApplication(testing: .live)
        try app.configure(TestArguments())

        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
        }
    }
}
