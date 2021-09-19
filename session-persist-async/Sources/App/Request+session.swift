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

import ExtrasBase64
import Foundation
import Hummingbird
import HummingbirdFoundation

private let sessionCookieName = "SESSION_ID"

extension HBRequest {
    struct Session {
        /// save session
        func save(userId: UUID, expiresIn: TimeAmount) async throws {
            let sessionId = Self.createSessionId()
            // prefix with "hbs."
            try await self.request.persist.set(
                key: "hbs.\(sessionId)",
                value: userId,
                expires: expiresIn
            )
            setId(sessionId)
        }

        /// load session
        func load() async throws -> UUID? {
            guard let sessionId = getId() else { return nil }
            // prefix with "hbs."
            return try await self.request.persist.get(key: "hbs.\(sessionId)", as: UUID.self)
        }

        /// Get session id gets id from request
        func getId() -> String? {
            guard let sessionCookie = request.cookies[sessionCookieName]?.value else { return nil }
            return String(sessionCookie)
        }

        /// set session id on response
        func setId(_ id: String) {
            self.request.response.setCookie(.init(name: sessionCookieName, value: String(describing: id)))
        }

        static func createSessionId() -> String {
            let bytes: [UInt8] = (0..<32).map { _ in UInt8.random(in: 0...255) }
            return String(base64Encoding: bytes)
        }

        let request: HBRequest
    }

    /// access session info
    var session: Session { return Session(request: self) }
}
