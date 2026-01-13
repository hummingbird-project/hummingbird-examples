import AsyncAlgorithms
import Foundation
import Hummingbird
import HummingbirdWebSocket
import ServiceLifecycle
import Synchronization
import Valkey

struct ChatController {
    let valkey: ValkeyClient
    let maxAgeOfLoadedMessages: Int
    let channelPrefix = "chat/Channel/"
    let listPrefix = "chat/List/"

    var routes: RouteCollection<BasicWebSocketRequestContext> {
        let routes = RouteCollection(context: BasicWebSocketRequestContext.self)

        routes.ws("api/chat") { request, _ in
            // only allow upgrade if username and channel query parameters exist
            guard request.uri.queryParameters["username"] != nil,
                request.uri.queryParameters["channel"] != nil
            else {
                return .dontUpgrade
            }
            return .upgrade([:])
        } onUpgrade: { inbound, outbound, context in
            let username = try context.request.uri.queryParameters.require("username")
            let channelName = try context.request.uri.queryParameters.require("channel")
            /// Setup key names
            let messagesChannel = "\(self.channelPrefix)\(channelName)"
            let messagesKey = ValkeyKey("\(self.listPrefix)\(channelName)")

            await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    /// Read messages from WebSocket
                    for try await wsMessage in inbound.messages(maxSize: 1_000_000) {
                        // Ignore non text frames
                        guard case .text(let message) = wsMessage else { continue }

                        // construct message text
                        let messageText = "[\(username)] - \(message)"

                        // Add to message stream and publish to channel
                        let responses = await self.valkey.execute(
                            XADD(
                                messagesKey,
                                idSelector: .autoId,
                                data: [
                                    .init(field: "username", value: "\(username)"),
                                    .init(field: "message", value: "\(message)"),
                                ]
                            ),
                            PUBLISH(channel: messagesChannel, message: messageText)
                        )
                        _ = try responses.1.get()
                    }
                }

                group.addTask {
                    // Read messages already posted. (limit message to those no older than `maxAgeOfLoadedMessages` seconds)
                    let id = "\((Int(Date.now.timeIntervalSince1970) - maxAgeOfLoadedMessages) * 1000)"
                    do {
                        let messages = try await self.valkey.xrange(
                            messagesKey,
                            start: id,
                            end: "+"
                        )
                        // write those messages to the websocket
                        for message in messages {
                            guard let username = message[field: "username"].map({ String($0) }),
                                let message = message[field: "message"].map({ String($0) })
                            else {
                                continue
                            }
                            try await outbound.write(.text("[\(username)] - \(message)"))
                        }
                    } catch {
                        print("\(error)")
                    }

                    /// Subscribe to channel and write any messages we receive to websocket
                    try await valkey.subscribe(to: [messagesChannel]) { subscription in
                        try await cancelWhenGracefulShutdown {
                            for try await event in subscription {
                                let message = String(event.message)
                                try await outbound.write(.text(message))
                            }
                        }
                    }
                }
            }
        }
        return routes
    }
}
