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

import Hummingbird
import HummingbirdWebSocket
import Logging
import NIOConcurrencyHelpers
import ServiceLifecycle

struct ConnectionManager: Service {
    struct Connection {
        let name: String
        let inbound: WebSocketInboundStream
        let outbound: WebSocketOutboundWriter
        let continuation: CheckedContinuation<Void, Never>
    }

    actor OutboundConnections {
        typealias Writer = WebSocketOutboundWriter
        init() {
            self.outboundWriters = [:]
        }

        func send(_ output: String) async throws {
            for outbound in self.outboundWriters.values {
                try await outbound.write(.text(output))
            }
        }

        func add(name: String, outbound: Writer) async throws {
            self.outboundWriters[name] = outbound
            try await self.send("\(name) joined")
        }

        func remove(name: String) async throws {
            self.outboundWriters[name] = nil
            try await self.send("\(name) left")
        }

        var outboundWriters: [String: Writer]
    }

    let connectionStream: AsyncStream<Connection>
    let connectionContinuation: AsyncStream<Connection>.Continuation
    let logger: Logger

    init(logger: Logger) {
        self.logger = logger
        (self.connectionStream, self.connectionContinuation) = AsyncStream<Connection>.makeStream()
    }

    func run() async {
        await withGracefulShutdownHandler {
            await withDiscardingTaskGroup { group in
                let outboundCounnections = OutboundConnections()
                for await connection in self.connectionStream {
                    self.logger.info("add connection", metadata: ["name": .string(connection.name)])
                    try? await outboundCounnections.add(name: connection.name, outbound: connection.outbound)
                    group.addTask {
                        do {
                            for try await input in connection.inbound {
                                guard case .text(let text) = input else { continue }
                                let output = "[\(connection.name)]: \(text)"
                                self.logger.debug("Output", metadata: ["message": .string(output)])
                                try? await outboundCounnections.send(output)
                            }
                            self.logger.info("remove connection", metadata: ["name": .string(connection.name)])
                            try? await outboundCounnections.remove(name: connection.name)
                        } catch {}
                        connection.continuation.resume()
                    }
                }
            }
        } onGracefulShutdown: {
            self.connectionContinuation.finish()
        }
    }

    func manageUser(name: String, inbound: WebSocketInboundStream, outbound: WebSocketOutboundWriter) async {
        await withCheckedContinuation { cont in
            let connection = Connection(name: name, inbound: inbound, outbound: outbound, continuation: cont)
            self.connectionContinuation.yield(connection)
        }
    }
}
