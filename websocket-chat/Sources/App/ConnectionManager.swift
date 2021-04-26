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
    class ConnectionManager {
        init() {
            self.lock = .init()
            self.map = [:]
        }

        /// Called when a new user joins
        func newUser(name: String, ws: HBWebSocket) {
            // add to list of connections
            self.add(name: name, ws: ws)
            // output joined text
            self.textOutput("\(name) has joined")
            // send ping and wait for pong and repeat every 60 seconds
            ws.initiateAutoPing(interval: .seconds(60))
            // if connection is closed, remove from list of connections
            ws.onClose { _ in
                self.remove(name: name)
                self.textOutput("\(name) has left")
            }
            // on reading input from websocket output to all websockets, with tag indicating who input is from
            ws.onRead { data, _ in
                switch data {
                case .text(let text):
                    self.textOutput("[\(name)]: \(text)")
                default:
                    break
                }
            }
        }

        /// output text to all connections
        func textOutput(_ text: String) {
            let webSockets = self.lock.withLock {
                map.values
            }
            webSockets.forEach {
                $0.write(.text(text))
            }
        }

        func get(name: String) -> HBWebSocket? {
            self.lock.withLock {
                map[name]
            }
        }

        /// Add to list of connections
        private func add(name: String, ws: HBWebSocket) {
            self.lock.withLock {
                map[name] = ws
            }
        }

        /// Remove from list of connections
        private func remove(name: String) {
            self.lock.withLock {
                map[name] = nil
            }
        }

        private var lock: Lock
        private var map: [String: HBWebSocket]
    }

    var connectionMgr: ConnectionManager {
        get { return self.extensions.get(\.connectionMgr) }
        set { return self.extensions.set(\.connectionMgr, value: newValue) }
    }
}
