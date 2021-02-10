import FluentKit
import Foundation
import Hummingbird
import HummingbirdAuth

/// Database description of a session
final class SessionData: Model {
    static let schema = "session"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user-id")
    var user: User

    @Field(key: "expires")
    var expires: Date

    internal init() { }

    internal init(id: UUID? = nil, userId: UUID, expires: Date) {
        self.id = id
        self.$user.id = userId
        self.expires = expires
    }
}
