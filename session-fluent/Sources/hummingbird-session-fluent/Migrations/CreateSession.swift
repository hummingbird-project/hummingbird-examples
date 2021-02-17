import FluentKit

struct CreateSession: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("session")
            .id()
            .field("user-id", .uuid, .required, .references("user", "id"))
            .field("expires", .date, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("user").delete()
    }
}

