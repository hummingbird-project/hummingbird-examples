import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import App

struct AppTests {
    struct TestArguments: AppArguments {
        var hostname: String { "127.0.0.1" }
        var port: Int { 0 }
    }

    @Test
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
                #expect(response.status == .ok)
                let bodyString = String(buffer: response.body)
                #expect(bodyString.contains(testFileName))
            }

            try await client.execute(uri: "/files/\(testFileName)", method: .get) { response in
                let downloadString = String(buffer: response.body)
                #expect(downloadString == textString, "Downloaded bytes should match uploaded bytes")
            }
        }
    }

    @Test
    func testUploadDownload2() async throws {
        let app = buildApplication(args: TestArguments())

        try await app.test(.ahc(.http)) { client in
            await withThrowingTaskGroup(of: Void.self) { group in
                // 10 threads
                for i in 0...10 {
                    group.addTask {
                        // 50 mb using the live test config
                        try await self.runUploadTest(client, i, 50)
                    }
                }
            }
        }
    }

    func runUploadTest(
        _ client: any TestClientProtocol,
        _ i: Int,
        _ size: Int = 1
    ) async throws {
        var bytes = [UInt8](repeating: 0, count: 1024 * 1024 * size)
        for j in 0...100 {
            bytes[j] = UInt8(j + i)
        }

        let buffer = ByteBuffer(bytes: bytes)
        let testFileName = "Hello-\(i).txt"
        let testUpload = UploadModel(filename: testFileName)
        let uploadURL = try testUpload.destinationURL(allowsOverwrite: true)
        defer {
            try? FileManager.default.removeItem(at: uploadURL)
        }
        print("---upload--- \(testFileName)")
        try await client.execute(
            uri: "/files",
            method: .post,
            headers: [.fileName: testFileName],
            body: buffer
        ) { response in
            #expect(response.status == .ok)
        }

        print("--download-- \(testFileName)")
        try await client.execute(uri: "/files/\(testFileName)", method: .get) { response in
            let dlBytes = response.body.getBytes(at: 0, length: response.body.readableBytes)

            #expect(dlBytes == bytes, "Downloaded bytes should match uploaded bytes")
        }

        print("--downloaded-- \(testFileName)")
    }
}
