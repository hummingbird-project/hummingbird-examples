@testable import App
import Hummingbird
import HummingbirdTesting
import XCTest

final class AppTests: XCTestCase {
    struct TestArguments: AppArguments {
        var hostname: String { "127.0.0.1" }
        var port: Int { 0 }
    }

    func testUploadDownload() async throws {
        let app = buildApplication(args: TestArguments())

        try await app.test(.live) { client in
            let textString = "Hello, World!"
            let testFileName = "Hello.txt"
            let testUpload = UploadModel(filename: testFileName)
            let uploadURL = try testUpload.destinationURL(allowsOverwrite: true)
            defer {
                try? FileManager.default.removeItem(at: uploadURL)
            }
            let buffer = ByteBuffer(string: textString)

            try await client.execute(
                uri: "/files",
                method: .post,
                headers: [.fileName: testFileName],
                body: buffer
            ) { response in
                XCTAssertEqual(response.status, .ok)
                let bodyString = String(buffer: response.body)
                XCTAssertTrue(bodyString.contains(testFileName))
            }

            try await client.execute(uri: "/files/\(testFileName)", method: .get) { response in
                let downloadString = String(buffer: response.body)
                XCTAssertEqual(downloadString, textString, "Downloaded bytes should match uploaded bytes")
            }
        }
    }
}
