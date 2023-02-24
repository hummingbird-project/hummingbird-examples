import FluentKit

struct CreateUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("user")
            .id()
            .field("username", .string, .required)
            .unique(on: "username")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("user").delete()
    }
}
