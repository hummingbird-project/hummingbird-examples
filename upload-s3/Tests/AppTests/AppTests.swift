@testable import App
import Hummingbird
import HummingbirdXCT
import XCTest

final class AppTests: XCTestCase {
    struct TestArguments: AppArguments {}

    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func testUploadDownload() throws {
        try XCTSkipIf(HBEnvironment().get("CI") != nil)

        let args = TestArguments()
        let app = HBApplication(testing: .live)
        try app.configure(args)

        try app.XCTStart()
        defer { XCTAssertNoThrow(app.XCTStop()) }

        let buffer = self.randomBuffer(size: 278)
        let filename = try app.XCTExecute(
            uri: "/files",
            method: .POST,
            headers: ["content-length": buffer.readableBytes.description],
            body: buffer
        ) { response -> String in
            let body = try XCTUnwrap(response.body)
            let json = try JSONDecoder().decode(S3FileController.UploadModel.self, from: body)
            return json.filename
        }

        let buffer2 = try app.XCTExecute(uri: "/files/\(filename)", method: .GET) { response -> ByteBuffer in
            let body = try XCTUnwrap(response.body)
            return body
        }

        XCTAssertEqual(buffer, buffer2)
    }

    func testFilename() throws {
        try XCTSkipIf(HBEnvironment().get("CI") != nil)

        let args = TestArguments()
        let app = HBApplication(testing: .live)
        try app.configure(args)

        try app.XCTStart()
        defer { XCTAssertNoThrow(app.XCTStop()) }

        let buffer = self.randomBuffer(size: 354_001)
        let filename = try app.XCTExecute(
            uri: "/files",
            method: .POST,
            headers: [
                "content-length": buffer.readableBytes.description,
                "file-name": "testFilename",
            ],
            body: buffer
        ) { response -> String in
            let body = try XCTUnwrap(response.body)
            let json = try JSONDecoder().decode(S3FileController.UploadModel.self, from: body)
            return json.filename
        }
        XCTAssertEqual(filename, "testFilename")
        let buffer2 = try app.XCTExecute(uri: "/files/\(filename)", method: .GET) { response -> ByteBuffer in
            let body = try XCTUnwrap(response.body)
            return body
        }

        XCTAssertEqual(buffer, buffer2)
    }
}
