//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AsyncAlgorithms
import Hummingbird
import HummingbirdWebSocket
import Logging
import NIOConcurrencyHelpers
import ServiceLifecycle

struct ConnectionManager: Service {
    enum Output {
        case close(String?)
        case frame(WebSocketOutboundWriter.OutboundFrame)
    }

    typealias OutputStream = AsyncChannel<Output>
    struct Connection {
        let name: String
        let inbound: WebSocketInboundStream
        let outbound: OutputStream
    }

    /// An actor is used to manage the outbound connections in a thread safe manner
    /// This is required because the websocket connection can be opened and closed on different threads
    /// 
    /// In a production setting, you would also want to use an event broker like Redis or Kafka of sorts.
    /// That way, you can horizontally scale your application by adding more instances of this service.
    actor OutboundConnections {
        init() {
            self.outboundWriters = [:]
        }

        func send(_ output: String) async {
            for outbound in self.outboundWriters.values {
                await outbound.send(.frame(.text(output)))
            }
        }

        func add(name: String, outbound: OutputStream) async -> Bool {
            guard self.outboundWriters[name] == nil else { return false }
            self.outboundWriters[name] = outbound
            await self.send("\(name) joined")
            return true
        }

        func remove(name: String) async {
            self.outboundWriters[name] = nil
            await self.send("\(name) left")
        }

        var outboundWriters: [String: OutputStream]
    }

    /// A stream of new connections being accepted by the server
    let connectionStream: AsyncStream<Connection>

    /// A continuation for the connection stream, that can emit new signals
    private let connectionContinuation: AsyncStream<Connection>.Continuation

    /// A logger for the connection manager
    let logger: Logger

    init(logger: Logger) {
        self.logger = logger
        (self.connectionStream, self.connectionContinuation) = AsyncStream<Connection>.makeStream()
    }

    func run() async {
        /// The `withGracefulShutdownHandler` is a helper that will call the `onGracefulShutdown` closure
        /// when the application is shutting down.
        /// 
        /// This helps ensure that the application will not exit before the connection manager has a chance to
        /// clean up all the connections.
        await withGracefulShutdownHandler {
            /// The `withDiscardingTaskGroup` is a task group that can indefinitely add tasks to it.
            /// As opposed to a regular task group, it will not incur memory overhead for each task added.
            /// This allows it to scale for a large number of tasks.
            await withDiscardingTaskGroup { group in
                // The OutboundConnections actor is used to manage the outbound connections in a thread safe manner
                // Allowing us to broadcast messages to all the connected clients
                let outboundCounnections = OutboundConnections()

                // As each client connects, the for loop will emit the next connection
                for await connection in self.connectionStream {
                    // Each client connection is handled in a new task, so their work is parallelized
                    group.addTask {
                        self.logger.info("add connection", metadata: ["name": .string(connection.name)])

                        // Add the client to the list of connected clients
                        guard await outboundCounnections.add(name: connection.name, outbound: connection.outbound) else {
                            // If the client already exists, we close the connection and return out of the Task
                            self.logger.info("user already exists", metadata: ["name": .string(connection.name)])
                            await connection.outbound.send(.close("User connected already"))
                            connection.outbound.finish()
                            return
                        }

                        do {
                            // We handle the stream as incoming messages emitted by this client
                            // The `for try await` loop will suspend until a new message is available
                            // Once a message is available, the message is handled before awaiting the next one
                            // This implicitly applies "backpressure" to the client, to prevent it from sending too many messages
                            // which would've otherwise overwhelmed the server
                            for try await input in connection.inbound.messages(maxSize: 1_000_000) {
                                // We only handle text messages
                                guard case .text(let text) = input else { continue }
                                // We create a new message with the client's name and the message content
                                let output = "[\(connection.name)]: \(text)"
                                self.logger.debug("Output", metadata: ["message": .string(output)])
                                // We send the message to all the connected clients
                                await outboundCounnections.send(output)
                            }
                        } catch {}

                        // When the connection is closed, we remove the client from the list of connected clients
                        self.logger.info("remove connection", metadata: ["name": .string(connection.name)])
                        await outboundCounnections.remove(name: connection.name)
                        connection.outbound.finish()
                    }
                }

                // Once the server is shutting down, the for loop will finish
                // This leads to this line, where we cancel all the tasks in the task group
                // The cancellation will in turn close the `messages` iterator for each connection
                // That will cause all connections to be cleaned up, allowing the application to exit
                group.cancelAll()
            }
        } onGracefulShutdown: {
            /// Closes the connection stream, which will stop the server from handling new connections
            self.connectionContinuation.finish()
        }
    }

    func addUser(name: String, inbound: WebSocketInboundStream, outbound: WebSocketOutboundWriter) -> OutputStream {
        let outputStream = OutputStream()
        let connection = Connection(name: name, inbound: inbound, outbound: outputStream)
        self.connectionContinuation.yield(connection)
        return outputStream
    }
}
