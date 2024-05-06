@testable import App
import Hummingbird
import HummingbirdTesting
import Logging
import XCTest

final class AppTests: XCTestCase {
    struct TestArguments: AppArguments {
        let hostname = "127.0.0.1"
        let port = 8080
        let logLevel: Logger.Level? = .trace
    }

    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func testUploadDownload() async throws {
        try XCTSkipIf(Environment().get("CI") != nil)

        let app = buildApplication(TestArguments())

        try await app.test(.router) { client in
            let buffer = self.randomBuffer(size: 278)
            let filename = try await client.execute(
                uri: "/files",
                method: .post,
                headers: [.contentLength: buffer.readableBytes.description],
                body: buffer
            ) { response -> String in
                let json = try JSONDecoder().decode(S3FileController.UploadModel.self, from: response.body)
                return json.filename
            }

            let buffer2 = try await client.execute(uri: "/files/\(filename)", method: .get) { response -> ByteBuffer in
                return response.body
            }

            XCTAssertEqual(buffer, buffer2)
        }
    }

    func testFilename() async throws {
        try XCTSkipIf(Environment().get("CI") != nil)

        let app = buildApplication(TestArguments())

        try await app.test(.router) { client in
            let buffer = self.randomBuffer(size: 354_001)
            let filename = try await client.execute(
                uri: "/files",
                method: .post,
                headers: [
                    .contentLength: buffer.readableBytes.description,
                    .fileName: "testFilename",
                ],
                body: buffer
            ) { response -> String in
                let json = try JSONDecoder().decode(S3FileController.UploadModel.self, from: response.body)
                return json.filename
            }
            XCTAssertEqual(filename, "testFilename")
            let buffer2 = try await client.execute(uri: "/files/\(filename)", method: .get) { response -> ByteBuffer in
                return response.body
            }

            XCTAssertEqual(buffer, buffer2)
        }
    }
}
