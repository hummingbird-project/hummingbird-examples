import FluentSQLiteDriver
import Foundation
import HummingbirdAuth
import HummingbirdFluent
import WebAuthn

final class User: Model, HBAuthenticatable, HBResponseEncodable {
    static let schema = "user"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "username")
    var username: String

    init() {}

    init(username: String) {
        self.username = username
    }
}

extension User: WebAuthnUser {
    var userID: String { self.id!.uuidString }
    var name: String { self.username }
    var displayName: String { self.username }
}
