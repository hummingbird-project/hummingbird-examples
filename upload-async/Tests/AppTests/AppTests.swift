@testable import App
import Hummingbird
import HummingbirdXCT
import XCTest

final class AppTests: XCTestCase {
    func testApp() throws {
        let app = HBApplication(testing: .live)
        try app.configure()

        try app.XCTStart()
        defer { app.XCTStop() }

        let textString = "Hello, World!"
        let testFileName = "Hello.txt"
        let buffer = ByteBufferAllocator().buffer(string: textString)

        app.XCTExecute(uri: "/upload",
                       method: .POST,
                       headers: ["File-Name" : testFileName],
                       body: buffer) { response in
            XCTAssertEqual(response.status, .ok)
            guard let body = response.body else {
                XCTFail("Response should contain a valid body")
                return
            }
            XCTAssertTrue(body.contains(string: testFileName))
        }
    }
}

fileprivate extension ByteBuffer {
    func contains(string: String) -> Bool {
        return String(buffer: self).contains(string)
    }
}
