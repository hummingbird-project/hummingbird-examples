import FluentSQLiteDriver
import Foundation
import HummingbirdAuth
import HummingbirdFluent
import WebAuthn

final class WebAuthnCredential: Model, @unchecked Sendable {
    static let schema = "webauthn_credential"

    @ID(custom: "id", generatedBy: .user)
    var id: String?

    @Field(key: "public_key")
    var publicKey: EncodedBase64

    @Parent(key: "user_id")
    var user: User

    init() {}

    private init(id: String, publicKey: EncodedBase64, userId: UUID) {
        self.id = id
        self.publicKey = publicKey
        self.$user.id = userId
    }

    convenience init(credential: Credential, userId: UUID) {
        self.init(
            id: credential.id,
            publicKey: credential.publicKey.base64EncodedString(),
            userId: userId
        )
    }
}
