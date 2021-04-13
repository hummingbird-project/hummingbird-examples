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

        let urlencoded = "name=Adam&age=34"
        app.XCTExecute(
            uri: "/",
            method: .POST,
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            body: ByteBufferAllocator().buffer(string: urlencoded)
        ) { response in
            XCTAssertEqual(response.headers["content-type"].first, "text/html")
            XCTAssertEqual(response.status, .ok)
        }
    }
}
