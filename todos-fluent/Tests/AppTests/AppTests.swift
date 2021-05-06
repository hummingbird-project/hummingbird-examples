import App
import Hummingbird
import HummingbirdXCT
import XCTest

final class AppTests: XCTestCase {
    struct TestArguments: AppArguments {
        var migrate: Bool { true }
        var inMemoryDatabase: Bool { true }
    }

    func testCreate() throws {
        let app = HBApplication(testing: .live)
        try app.configure(TestArguments())

        try app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(
            uri: "/todos",
            method: .POST,
            body: ByteBufferAllocator().buffer(string: #"{"title":"add more tests"}"#)) { response in
            XCTAssertEqual(response.status, .created)
        }
    }
}
