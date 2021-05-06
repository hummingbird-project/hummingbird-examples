import App
import Hummingbird
import HummingbirdXCT
import XCTest

final class AppTests: XCTestCase {
    struct TestArguments: AppArguments {
        var migrate: Bool { true }
        var inMemoryDatabase: Bool { true }
    }

    func testApp() throws {
        let app = HBApplication(testing: .live)
        try app.configure(TestArguments())

        try app.XCTStart()
        defer { app.XCTStop() }

        // create user
        app.XCTExecute(
            uri: "/user",
            method: .PUT,
            body: ByteBufferAllocator().buffer(string: #"{"name":"testuser", "password":"testpassword"}"#)
        ) { response in
            XCTAssertEqual(response.status, .ok)
        }
    }
}
