import FluentSQLiteDriver
import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent
import WebAuthn

final class User: Model, ResponseEncodable, @unchecked Sendable, Authenticatable {
    static let schema = "user"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "username")
    var username: String

    init() {}

    init(username: String) {
        self.username = username
    }

    var publicKeyCredentialUserEntity: PublicKeyCredentialUserEntity {
        get throws {
            try .init(id: .init(self.requireID().uuidString.utf8), name: self.username, displayName: self.username)
        }
    }
}
