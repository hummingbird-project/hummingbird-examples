import Foundation
import Hummingbird
@_spi(ConnectionPool) import PostgresNIO

struct TodoPostgresRepository: TodoRepository, Sendable {
    let client: PostgresClient
    let logger: Logger

    /// Create Todos table
    func createTable() async throws {
        _ = try await client.withConnection { connection in
            try await connection.query("""
                CREATE TABLE IF NOT EXISTS todos (
                    "id" uuid PRIMARY KEY,
                    "title" text NOT NULL,
                    "order" integer,
                    "completed" boolean,
                    "url" text
                )
                """,
                logger: logger
            )
        }
    }
    /// Create todo.
    func create(title: String, order: Int?, urlPrefix: String) async throws -> Todo {
        let id = UUID()
        let url = urlPrefix + id.uuidString
        _ = try await self.client.withConnection{ connection in 
            try await connection.query(
                "INSERT INTO todos (id, title, url, \"order\") VALUES (\(id), \(title), \(url), \(order));", 
                logger: logger
            )
        }
        return Todo(id: id, title: title, order: order, url: url, completed: nil)
    }
    /// Get todo.
    func get(id: UUID) async throws -> Todo? { 
        try await self.client.withConnection{ connection in
            let stream = try await connection.query("""
                SELECT "id", "title", "order", "url", "completed" FROM todos WHERE "id" = \(id)
                """, logger: logger
            )
            for try await (id, title, order, url, completed) in stream.decode((UUID, String, Int?, String, Bool?).self, context: .default) {
                return Todo(id: id, title: title, order: order, url: url, completed: completed)
            }
            return nil
        }
    }
    /// List all todos
    func list() async throws -> [Todo] { 
        try await self.client.withConnection { connection in
            let stream = try await connection.query("""
                SELECT "id", "title", "order", "url", "completed" FROM todos
                """, logger: logger
            )
            var todos: [Todo] = []
            for try await (id, title, order, url, completed) in stream.decode((UUID, String, Int?, String, Bool?).self, context: .default) {
                let todo = Todo(id: id, title: title, order: order, url: url, completed: completed)
                todos.append(todo)
            }
            return todos
        }
    }
    /// Update todo. Returns updated todo if successful
    func update(id: UUID, title: String?, order: Int?, completed: Bool?) async throws -> Todo? {
        return try await self.client.withConnection{ connection in 
            // UPDATE query
            let query: PostgresQuery = """
                UPDATE todos SET \(optionalUpdateFields: (("title", title), ("order", order), ("completed", completed))) WHERE id = \(id)
                """
            // if bind count is 1 then we aren't updating anything. Return nil
            if query.binds.count == 1 {
                return nil
            }
            _ = try await connection.query(query, logger: logger
            )
            // SELECT so I can get the full details of the TODO back
            let stream = try await connection.query("""
                SELECT "id", "title", "order", "url", "completed" FROM todos WHERE "id" = \(id)
                """, logger: logger
            )
            for try await (id, title, order, url, completed) in stream.decode((UUID, String, Int?, String, Bool?).self, context: .default) {
                return Todo(id: id, title: title, order: order, url: url, completed: completed)
            }
            return nil
        }
    }
    /// Delete todo. Returns true if successful
    func delete(id: UUID) async throws -> Bool {
        return try await self.client.withConnection{ connection in
            let selectStream = try await connection.query("""
                SELECT "id" FROM todos WHERE "id" = \(id)
                """, logger: logger
            )
            // if we didn't find the item with this id then return false
            if try await selectStream.decode((UUID).self, context: .default).first(where: { _ in true} ) == nil {
                return false
            }
            _ = try await connection.query("DELETE FROM todos WHERE id = \(id);", logger: logger)
            return true
        }
    }
    /// Delete all todos
    func deleteAll() async throws {
        return try await self.client.withConnection{ connection in
            try await connection.query("DELETE FROM todos;", logger: logger)
        }
    }
}

extension PostgresQuery.StringInterpolation {
    /// Append interpolation of a series of fields with optional values for a SQL UPDATE call. 
    /// If the value is nil it doesn't add the field to the query.
    /// 
    /// This call only works if you have more than one field.
    mutating func appendInterpolation<each Value: PostgresDynamicTypeEncodable>(optionalUpdateFields fields: (repeat (String, Optional<each Value>))) {
        func appendSelect(id: String, value: Optional<some PostgresDynamicTypeEncodable>, first: Bool) -> Bool {
            if let value {
                self.appendInterpolation(unescaped: "\(first ? "": ", ")\(id) = ")
                self.appendInterpolation(value)
                return false
            }
            return first
        }
        var first: Bool = true // indicates whether we should prefix with a comma
        repeat (
            first = appendSelect(id: (each fields).0, value: (each fields).1, first: first)
        )
    }
}