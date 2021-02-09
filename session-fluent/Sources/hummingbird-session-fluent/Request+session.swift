import Foundation
import Hummingbird
import HummingbirdFoundation

extension HBRequest {
    struct Session {
        static let cookieName = "SESSION_ID"

        /// Get session id gets id from request
        func getId() -> UUID? {
            guard let sessionCookie = request.cookies["SESSION_ID"]?.value else { return nil }
            return UUID(sessionCookie)
        }
        /// set session id on response
        func setId(_ id: UUID) {
            request.response.setCookie(.init(name: Self.cookieName, value: id.uuidString))
        }

        let request: HBRequest
    }

    /// access session info
    var session: Session { return Session(request: self) }
}
