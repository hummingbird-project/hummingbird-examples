import App
import Hummingbird
import HummingbirdXCT
import XCTest

final class AppTests: XCTestCase {
    func testCreate() throws {
        try XCTSkipIf(HBEnvironment().get("CI") != nil)

        let app = HBApplication(testing: .live)
        try app.configure()

        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(
            uri: "/todos",
            method: .POST,
            body: ByteBufferAllocator().buffer(string: #"{"title":"add more tests"}"#)
        ) { response in
            XCTAssertEqual(response.status, .created)
        }
    }
}
