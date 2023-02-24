import FluentKit

struct CreateWebAuthnCredential: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("webauthn_credential")
            .field("id", .string, .identifier(auto: false))
            .field("public_key", .string, .required)
            .field("user_id", .uuid, .required, .references("user", "id"))
            .unique(on: "id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("webauthn_credential").delete()
    }
}
