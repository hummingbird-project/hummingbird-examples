import FluentSQLiteDriver
import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent
import WebAuthn

final class User: Model, ResponseEncodable {
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
