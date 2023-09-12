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
import NIOConcurrencyHelpers

extension HBApplication {
    actor ConnectionManager {
        init() {
            self.map = [:]
        }

        /// Called when a new user joins
        func newUser(name: String, ws: HBWebSocket) {
            // add to list of connections
            self.add(name: name, ws: ws)
            // send ping and wait for pong and repeat every 60 seconds
            ws.initiateAutoPing(interval: .seconds(60))

            Task {
                // output joined text
                try await self.textOutput("\(name) has joined")
                let stream = ws.readStream()
                for await data in stream {
                    switch data {
                    case .text(let text):
                        try? await self.textOutput("[\(name)]: \(text)")
                    default:
                        break
                    }
                }
                self.remove(name: name)
                try await self.textOutput("\(name) has left")
            }
        }

        /// output text to all connections
        func textOutput(_ text: String) async throws {
            for webSocket in map.values {
                try await webSocket.write(.text(text))
            }
        }

        func get(name: String) -> HBWebSocket? {
            map[name]
        }

        /// Add to list of connections
        private func add(name: String, ws: HBWebSocket) {
            map[name] = ws
        }

        /// Remove from list of connections
        private func remove(name: String) {
            map[name] = nil
        }

        private var map: [String: HBWebSocket]
    }

    var connectionMgr: ConnectionManager {
        get { return self.extensions.get(\.connectionMgr) }
        set { return self.extensions.set(\.connectionMgr, value: newValue) }
    }
}
