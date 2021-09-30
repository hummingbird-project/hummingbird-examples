import App
import Hummingbird
import HummingbirdXCT
import XCTest

final class AppTests: XCTestCase {
    func testApp() throws {
        let app = HBApplication(testing: .live)
        try app.configure()

        try app.XCTStart()
        defer { app.XCTStop() }

        let multipartForm = """
        ------HBTestFormBoundaryXD6BXJI\r
        Content-Disposition: form-data; name="name"\r
        \r
        adam\r
        ------HBTestFormBoundaryXD6BXJI\r
        Content-Disposition: form-data; name="age"\r
        \r
        50\r
        ------HBTestFormBoundaryXD6BXJI--\r
        """
        let contentType = "multipart/form-data; boundary=----HBTestFormBoundaryXD6BXJI"
        app.XCTExecute(
            uri: "/",
            method: .POST,
            headers: ["content-type": contentType],
            body: ByteBufferAllocator().buffer(string: multipartForm)
        ) { response in
            XCTAssertEqual(response.status, .ok)
        }
    }
}
