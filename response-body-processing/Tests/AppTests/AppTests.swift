import Crypto
import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import Testing

@testable import App

final class AppTests {
    struct TestArguments: AppArguments {
        let hostname = "127.0.0.1"
        let port = 0
        let logLevel: Logger.Level? = .trace
    }

    static func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    @Test func testApp() async throws {
        let args = TestArguments()
        let app = try await buildApplication(args)
        let buffer = Self.randomBuffer(size: 256 * 000)
        let digest = SHA256.hash(data: Data(buffer.readableBytesView))
        try await app.test(.live) { client in
            try await client.execute(uri: "/echo", method: .post, body: buffer) { response in
                #expect(
                    response.trailerHeaders?[.digest] == "sha256=\(digest.hexDigest())"
                )
            }
        }
    }
}
