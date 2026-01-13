import Hummingbird
import HummingbirdTesting
import HummingbirdWSClient
import HummingbirdWSTesting
import Logging
import NIOWebSocket
import Testing

@testable import App

struct AppTests {
    struct TestArguments: AppArguments {
        let hostname = "localhost"
        let port = 8080
        let maxAgeOfLoadedMessages = 2
    }

    @Test
    func testUpgradeFail() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.live) { client in
            do {
                _ = try await client.ws("/api/chat") { inbound, outbound, context in
                    Issue.record("Upgrade failed so shouldn't get here")
                }
            } catch let error as WebSocketClientError where error == .webSocketUpgradeFailed {}
        }
    }

    @Test
    func testHello() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.live) { client in
            _ = try await client.ws("/api/chat?username=john&channel=TestHello") { inbound, outbound, context in
                let expectedInboundText = [
                    "[john] - Hello"
                ]
                try await outbound.write(.text("Hello"))
                var inboundIterator = inbound.messages(maxSize: 1 << 16).makeAsyncIterator()
                for text in expectedInboundText {
                    let frame = try await inboundIterator.next()
                    #expect(frame == .text(text))
                }
            }
        }
    }

    @Test
    func testTwoClients() async throws {
        enum ChatAction {
            case send(String)
            case receive(String)
        }
        let app = try await buildApplication(TestArguments())
        try await app.test(.live) { client in
            await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    _ = try await client.ws("/api/chat?username=john&channel=TestTwoClients") { inbound, outbound, context in
                        let actions: [ChatAction] = [
                            .send("Hello Jane"),
                            .receive("[john] - Hello Jane"),
                            .receive("[jane] - Hello John"),
                        ]
                        var inboundIterator = inbound.messages(maxSize: 1 << 16).makeAsyncIterator()
                        for action in actions {
                            switch action {
                            case .send(let text):
                                try await outbound.write(.text(text))
                            case .receive(let text):
                                let frame = try await inboundIterator.next()
                                #expect(frame == .text(text))
                            }
                        }
                    }
                }
                group.addTask {
                    // add stall to ensure john joins first
                    try await Task.sleep(for: .milliseconds(100))
                    _ = try await client.ws("/api/chat?username=jane&channel=TestTwoClients") { inbound, outbound, context in
                        let actions: [ChatAction] = [
                            .receive("[john] - Hello Jane"),
                            .send("Hello John"),
                            .receive("[jane] - Hello John"),
                        ]
                        var inboundIterator = inbound.messages(maxSize: 1 << 16).makeAsyncIterator()
                        for action in actions {
                            switch action {
                            case .send(let text):
                                try await outbound.write(.text(text))
                            case .receive(let text):
                                let frame = try await inboundIterator.next()
                                #expect(frame == .text(text))
                            }
                        }
                    }
                }
            }
        }
    }
}
