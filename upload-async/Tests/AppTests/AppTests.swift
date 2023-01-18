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
        let testUpload = UploadModel(filename: testFileName)
        let uploadURL = try testUpload.destinationURL(allowsOverwrite: true)
        defer {
            try? FileManager.default.removeItem(at: uploadURL)
        }
        let buffer = ByteBufferAllocator().buffer(string: textString)

        try app.XCTExecute(
            uri: "/files",
            method: .POST,
            headers: ["File-Name": testFileName],
            body: buffer
        ) { response in
            XCTAssertEqual(response.status, .ok)
            guard let body = response.body else {
                XCTFail("Response should contain a valid body")
                return
            }
            XCTAssertTrue(body.contains(string: testFileName))
        }

        try app.XCTExecute(uri: "/files/\(testFileName)", method: .GET) { response in
            guard let body = response.body else {
                XCTFail("Response should contain a valid body")
                return
            }
            let downloadString = String(buffer: body)
            XCTAssertEqual(downloadString, textString, "Downloaded bytes should match uploaded bytes")
        }
    }
}

private extension ByteBuffer {
    func contains(string: String) -> Bool {
        return String(buffer: self).contains(string)
    }
}
