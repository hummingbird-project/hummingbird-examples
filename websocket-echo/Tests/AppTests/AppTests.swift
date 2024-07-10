@testable import App
import Hummingbird
import HummingbirdTesting
import HummingbirdWebSocket
import HummingbirdWSTesting
import Logging
import ServiceLifecycle
import XCTest

final class AppTests: XCTestCase {
    struct TestArguments: AppArguments {
        let hostname = "localhost"
        let port = 8080
    }

    func testEchoText() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.live) { client in
            _ = try await client.ws("/echo") { inbound, outbound, context in
                try await outbound.write(.text("Hello"))
                var inboundIterator = inbound.messages(maxSize: .max).makeAsyncIterator()
                let frame = try await inboundIterator.next()
                XCTAssertEqual(frame, .text("Hello"))
            }
        }
    }

    func testEchoBinary() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.live) { client in
            _ = try await client.ws("/echo") { inbound, outbound, context in
                let byteBuffer = context.allocator.buffer(repeating: 5, count: 256)
                try await outbound.write(.binary(byteBuffer))
                var inboundIterator = inbound.messages(maxSize: .max).makeAsyncIterator()
                let frame = try await inboundIterator.next()
                XCTAssertEqual(frame, .binary(byteBuffer))
            }
        }
    }

    func testEchoContinuation() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.live) { client in
            _ = try await client.ws("/echo") { inbound, outbound, context in
                try await outbound.withTextMessageWriter { writer in
                    try await writer("Hello ")
                    try await writer("World!")
                }
                var inboundIterator = inbound.messages(maxSize: .max).makeAsyncIterator()
                let frame = try await inboundIterator.next()
                XCTAssertEqual(frame, .text("Hello World!"))
            }
        }
    }

    func testDisconnectText() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.live) { client in
            _ = try await client.ws("/echo") { inbound, outbound, context in
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for try await _ in inbound {}
                    }
                    try await outbound.write(.text("disconnect"))
                }
            }
        }
    }
}
