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

import FluentKit
import Foundation
import Hummingbird
import HummingbirdFoundation

extension HBRequest {
    struct Session {
        static let cookieName = "SESSION_ID"

        /// save session
        func save(userId: UUID, expiresIn: TimeAmount) -> EventLoopFuture<Void> {
            // create session lasting 1 hour
            let session = SessionData(userId: userId, expires: Date(timeIntervalSinceNow: TimeInterval(expiresIn.nanoseconds / 1_000_000_000)))
            // (userId: userId, expires: Date(timeIntervalSinceNow: expiresIn.nanoseconds / 1_000_000_000))
            return session.save(on: self.request.db)
                .flatMapThrowing {
                    guard let id = session.id else { throw HBHTTPError(.internalServerError) }
                    request.session.setId(id)
                }
        }

        /// load session
        func load() -> EventLoopFuture<User?> {
            guard let sessionId = getId() else { return self.request.success(nil) }
            // check if session exists in the database. If it is return related user
            return SessionData.query(on: self.request.db).with(\.$user)
                .filter(\.$id == sessionId)
                .first()
                .map { session -> User? in
                    guard let session = session else { return nil }
                    // has session expired
                    if session.expires.timeIntervalSinceNow > 0 {
                        return session.user
                    }
                    return nil
                }
        }

        /// Get session id gets id from request
        func getId() -> UUID? {
            guard let sessionCookie = request.cookies["SESSION_ID"]?.value else { return nil }
            return UUID(sessionCookie)
        }

        /// set session id on response
        func setId(_ id: UUID) {
            self.request.response.setCookie(.init(name: Self.cookieName, value: id.uuidString))
        }

        static func createSessionId() -> UUID {
            return UUID()
        }

        let request: HBRequest
    }

    /// access session info
    var session: Session { return Session(request: self) }
}
