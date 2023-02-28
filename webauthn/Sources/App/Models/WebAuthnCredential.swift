import FluentSQLiteDriver
import HummingbirdAuth
import HummingbirdFluent
import WebAuthn

final class WebAuthnCredential: Model {
    static let schema = "webauthn_credential"

    @ID(custom: "id", generatedBy: .user)
    var id: String?

    @Field(key: "public_key")
    var publicKey: String

    @Parent(key: "user_id")
    var user: User

    init() {}

    init(id: String, publicKey: String, userId: UUID) {
        self.id = id
        self.publicKey = publicKey
        self.$user.id = userId
    }

    convenience init(credential: Credential, userId: UUID) {
        self.init(
            id: credential.id,
            publicKey: credential.publicKey.base64URLEncodedString(),
            userId: userId
        )
    }
}
