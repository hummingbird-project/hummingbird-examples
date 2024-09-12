import Foundation
import Hummingbird
import PostgresNIO

struct TodoPostgresRepository: TodoRepository, Sendable {
    let client: PostgresClient
    let logger: Logger

    /// Create Todos table
    func createTable() async throws {
        try await self.client.query(
            """
            CREATE TABLE IF NOT EXISTS todos (
                "id" uuid PRIMARY KEY,
                "title" text NOT NULL,
                "order" integer,
                "completed" boolean,
                "url" text
            )
            """,
            logger: self.logger
        )
    }

    /// Create todo.
    func create(title: String, order: Int?, urlPrefix: String) async throws -> Todo {
        let id = UUID()
        let url = urlPrefix + id.uuidString
        // The string interpolation is building a PostgresQuery with bindings and is safe from sql injection
        try await self.client.query(
            "INSERT INTO todos (id, title, url, \"order\") VALUES (\(id), \(title), \(url), \(order));",
            logger: self.logger
        )
        return Todo(id: id, title: title, order: order, url: url, completed: nil)
    }

    /// Get todo.
    func get(id: UUID) async throws -> Todo? {
        // The string interpolation is building a PostgresQuery with bindings and is safe from sql injection
        let stream = try await self.client.query(
            """
            SELECT "id", "title", "order", "url", "completed" FROM todos WHERE "id" = \(id)
            """,
            logger: self.logger
        )
        for try await(id, title, order, url, completed) in stream.decode((UUID, String, Int?, String, Bool?).self, context: .default) {
            return Todo(id: id, title: title, order: order, url: url, completed: completed)
        }
        return nil
    }

    /// List all todos
    func list() async throws -> [Todo] {
        let stream = try await self.client.query(
            """
            SELECT "id", "title", "order", "url", "completed" FROM todos
            """,
            logger: self.logger
        )
        var todos: [Todo] = []
        for try await(id, title, order, url, completed) in stream.decode((UUID, String, Int?, String, Bool?).self, context: .default) {
            let todo = Todo(id: id, title: title, order: order, url: url, completed: completed)
            todos.append(todo)
        }
        return todos
    }

    /// Update todo. Returns updated todo if successful
    func update(id: UUID, title: String?, order: Int?, completed: Bool?) async throws -> Todo? {
        let query: PostgresQuery?
        // UPDATE query. Work out query based on whick values are not nil
        // The string interpolation is building a PostgresQuery with bindings and is safe from sql injection
        if let title {
            if let order {
                if let completed {
                    query = "UPDATE todos SET title = \(title), order = \(order), completed = \(completed) WHERE id = \(id)"
                } else {
                    query = "UPDATE todos SET title = \(title), order = \(order) WHERE id = \(id)"
                }
            } else {
                if let completed {
                    query = "UPDATE todos SET title = \(title), completed = \(completed) WHERE id = \(id)"
                } else {
                    query = "UPDATE todos SET title = \(title) WHERE id = \(id)"
                }
            }
        } else {
            if let order {
                if let completed {
                    query = "UPDATE todos SET order = \(order), completed = \(completed) WHERE id = \(id)"
                } else {
                    query = "UPDATE todos SET order = \(order) WHERE id = \(id)"
                }
            } else {
                if let completed {
                    query = "UPDATE todos SET completed = \(completed) WHERE id = \(id)"
                } else {
                    query = nil
                }
            }
        }
        if let query {
            _ = try await self.client.query(query, logger: self.logger)
        }

        // SELECT so I can get the full details of the TODO back
        // The string interpolation is building a PostgresQuery with bindings and is safe from sql injection
        let stream = try await self.client.query(
            """
            SELECT "id", "title", "order", "url", "completed" FROM todos WHERE "id" = \(id)
            """,
            logger: self.logger
        )
        for try await(id, title, order, url, completed) in stream.decode((UUID, String, Int?, String, Bool?).self, context: .default) {
            return Todo(id: id, title: title, order: order, url: url, completed: completed)
        }
        return nil
    }

    /// Delete todo. Returns true if successful
    func delete(id: UUID) async throws -> Bool {
        // The string interpolation is building a PostgresQuery with bindings and is safe from sql injection
        let selectStream = try await self.client.query(
            """
            SELECT "id" FROM todos WHERE "id" = \(id)
            """,
            logger: self.logger
        )
        // if we didn't find the item with this id then return false
        if try await selectStream.decode(UUID.self, context: .default).first(where: { _ in true }) == nil {
            return false
        }
        _ = try await self.client.query("DELETE FROM todos WHERE id = \(id);", logger: self.logger)
        return true
    }

    /// Delete all todos
    func deleteAll() async throws {
        try await self.client.query("DELETE FROM todos;", logger: self.logger)
    }
}
