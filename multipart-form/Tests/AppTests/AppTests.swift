@testable import App
import Hummingbird
import HummingbirdTesting
import NIOFileSystem
import XCTest

final class AppTests: XCTestCase {

    override func tearDown() async throws {
        // Clean up any created directories or files
        let contentDirectory = try await File.getContentDirectory()
        try await FileSystem.shared.removeItem(at: contentDirectory)
        try await super.tearDown()
    }

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
            ------HBTestFormBoundaryXD6BXJI\r
            Content-Disposition: form-data; name="profilePicture"; filename="example.txt"\r
            Content-Type: text/plain\r
            \r
            Hummingbird\r
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
