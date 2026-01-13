import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import Testing

@testable import App

@Suite("S3 Upload Tests", .disabled(if: Environment().get("CI") != nil, "Disabled in CI as it requires an S3 bucket"))
struct AppTests {
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

    @Test
    func testUploadDownload() async throws {
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
                response.body
            }

            #expect(buffer == buffer2)
        }
    }

    @Test
    func testFilename() async throws {

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
            #expect(filename == "testFilename")
            let buffer2 = try await client.execute(uri: "/files/\(filename)", method: .get) { response -> ByteBuffer in
                response.body
            }

            #expect(buffer == buffer2)
        }
    }
}
