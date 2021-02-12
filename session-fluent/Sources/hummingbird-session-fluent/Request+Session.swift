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
            //(userId: userId, expires: Date(timeIntervalSinceNow: expiresIn.nanoseconds / 1_000_000_000))
            return session.save(on: request.db)
                .flatMapThrowing {
                    guard let id = session.id else { throw HBHTTPError(.internalServerError) }
                    request.session.setId(id)
                }
        }

        /// load session
        func load() -> EventLoopFuture<User?> {
            guard let sessionId = getId() else { return request.success(nil) }
            // check if session exists in the database. If it is login related user
            return SessionData.query(on: request.db).with(\.$user)
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
            request.response.setCookie(.init(name: Self.cookieName, value: id.uuidString))
        }

        static func createSessionId() -> UUID {
            return UUID()
        }

        let request: HBRequest
    }

    /// access session info
    var session: Session { return Session(request: self) }
}
