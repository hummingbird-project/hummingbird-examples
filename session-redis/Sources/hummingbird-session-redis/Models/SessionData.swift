import Foundation

/// Database description of a session
final class SessionData: Codable {
    var userId: UUID
    var expires: Date

    internal init(userId: UUID, expires: Date) {
        self.userId = userId
        self.expires = expires
    }
}
