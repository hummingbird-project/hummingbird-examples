@testable import App
import Hummingbird
import HummingbirdTesting
import HummingbirdWSClient
import HummingbirdWSTesting
import NIOWebSocket
import XCTest

final class AppTests: XCTestCase {
    struct TestArguments: AppArguments {
        let hostname = "localhost"
        let port = 8080
    }

    func testUpgradeFail() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.live) { client in
            do {
                _ = try await client.ws("/chat") { inbound, outbound, context in
                    XCTFail("Upgrade failed so shouldn't get here")
                }
            } catch let error as WebSocketClientError where error == .webSocketUpgradeFailed {}
        }
    }

    func testHello() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.live) { client in
            _ = try await client.ws("/chat?username=john") { inbound, outbound, context in
                let expectedInboundText = [
                    "john joined",
                    "[john]: Hello",
                ]
                try await outbound.write(.text("Hello"))
                var inboundIterator = inbound.messages(maxSize: 1 << 16).makeAsyncIterator()
                for text in expectedInboundText {
                    let frame = try await inboundIterator.next()
                    XCTAssertEqual(frame, .text(text))
                }
            }
        }
    }

    func testTwoClients() async throws {
        enum ChatAction {
            case send(String)
            case receive(String)
        }
        let app = try await buildApplication(TestArguments())
        try await app.test(.live) { client in
            await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    _ = try await client.ws("/chat?username=john") { inbound, outbound, context in
                        let actions: [ChatAction] = [
                            .receive("john joined"),
                            .receive("jane joined"),
                            .send("Hello Jane"),
                            .receive("[john]: Hello Jane"),
                            .receive("[jane]: Hello John"),
                        ]
                        var inboundIterator = inbound.messages(maxSize: 1 << 16).makeAsyncIterator()
                        for action in actions {
                            switch action {
                            case .send(let text):
                                try await outbound.write(.text(text))
                            case .receive(let text):
                                let frame = try await inboundIterator.next()
                                XCTAssertEqual(frame, .text(text))
                            }
                        }
                    }
                }
                group.addTask {
                    // add stall to ensure john joins first
                    try await Task.sleep(for: .milliseconds(100))
                    _ = try await client.ws("/chat?username=jane") { inbound, outbound, context in
                        let actions: [ChatAction] = [
                            .receive("jane joined"),
                            .receive("[john]: Hello Jane"),
                            .send("Hello John"),
                            .receive("[jane]: Hello John"),
                        ]
                        var inboundIterator = inbound.messages(maxSize: 1 << 16).makeAsyncIterator()
                        for action in actions {
                            switch action {
                            case .send(let text):
                                try await outbound.write(.text(text))
                            case .receive(let text):
                                let frame = try await inboundIterator.next()
                                XCTAssertEqual(frame, .text(text))
                            }
                        }
                    }
                }
            }
        }
    }

    func testNameClash() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.live) { client in
            try await withThrowingTaskGroup(of: NIOWebSocket.WebSocketErrorCode?.self) { group in
                group.addTask {
                    return try await client.ws("/chat?username=john") { inbound, outbound, context in
                        try await Task.sleep(for: .milliseconds(100))
                    }?.closeCode
                }
                group.addTask {
                    return try await client.ws("/chat?username=john") { inbound, outbound, context in
                        try await Task.sleep(for: .milliseconds(100))
                    }?.closeCode
                }
                let rt1 = try await group.next()
                let rt2 = try await group.next()
                XCTAssert(rt1 == .unexpectedServerError || rt2 == .unexpectedServerError)
            }
        }
    }
}
