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

extension User {
    var publicKeyCredentialUserEntity: PublicKeyCredentialUserEntity {
        .init(id: .init(self.id!.uuidString.utf8), name: self.username, displayName: self.username)
    }
}
