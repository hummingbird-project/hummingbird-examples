import FluentKit

struct CreateTodo: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("todos")
            .id()
            .field("title", .string, .required)
            .field("order", .int)
            .field("completed", .bool)
            .field("url", .string)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("todos").delete()
    }
}

