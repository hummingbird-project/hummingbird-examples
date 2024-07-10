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
                    group.addTask {
                        self.logger.info("add connection", metadata: ["name": .string(connection.name)])
                        guard await outboundCounnections.add(name: connection.name, outbound: connection.outbound) else {
                            self.logger.info("user already exists", metadata: ["name": .string(connection.name)])
                            await connection.outbound.send(.close("User connected already"))
                            connection.outbound.finish()
                            return
                        }

                        do {
                            for try await input in connection.inbound.messages(maxSize: 1_000_000) {
                                guard case .text(let text) = input else { continue }
                                let output = "[\(connection.name)]: \(text)"
                                self.logger.debug("Output", metadata: ["message": .string(output)])
                                await outboundCounnections.send(output)
                            }
                        } catch {}

                        self.logger.info("remove connection", metadata: ["name": .string(connection.name)])
                        await outboundCounnections.remove(name: connection.name)
                        connection.outbound.finish()
                    }
                }
                group.cancelAll()
            }
        } onGracefulShutdown: {
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
