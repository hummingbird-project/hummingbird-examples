@testable import App
import Hummingbird
import HummingbirdTesting
import XCTest

final class AppTests: XCTestCase {
    struct TestArguments: AppArguments {
        let hostname = "127.0.0.1"
        let port = 8080
    }

    func testApp() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
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
            try await client.execute(
                uri: "/",
                method: .post,
                headers: [.contentType: contentType],
                body: ByteBufferAllocator().buffer(string: multipartForm)
            ) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }
}
