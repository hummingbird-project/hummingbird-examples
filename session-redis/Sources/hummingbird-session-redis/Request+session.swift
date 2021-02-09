import Foundation
import Hummingbird
import HummingbirdFoundation
import ExtrasBase64

private let sessionCookieName = "SESSION_ID"

extension HBRequest {
    struct SessionData: Codable {
        var userId: UUID
        var expires: Date

        internal init(userId: UUID, expires: Date) {
            self.userId = userId
            self.expires = expires
        }
    }

    struct Session {
        /// save session
        func save(session: SessionData) -> EventLoopFuture<Void> {
            let sessionId = Self.createSessionId()
            // prefix with "hbs."
            return request.redis.set("hbs.\(sessionId)", toJSON: session)
                .map { _ in setId(sessionId) }
        }

        /// load session
        func load() -> EventLoopFuture<SessionData?> {
            guard let sessionId = getId() else { return request.success(nil) }
            // prefix with "hbs."
            return request.redis.get("hbs.\(sessionId)", asJSON: SessionData.self)
        }

        /// Get session id gets id from request
        func getId() -> String? {
            guard let sessionCookie = request.cookies[sessionCookieName]?.value else { return nil }
            return String(sessionCookie)
        }

        /// set session id on response
        func setId(_ id: String) {
            request.response.setCookie(.init(name: sessionCookieName, value: String(describing: id)))
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

