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
            // construct query using the StringInterpolation
            var updatedValue = false
            var query = PostgresQuery.StringInterpolation(literalCapacity: 3, interpolationCount: 3)
            query.appendInterpolation(unescaped: "UPDATE todos SET")
            if let title {
                query.appendInterpolation(unescaped: " \"title\" = ")
                query.appendInterpolation(title)
                updatedValue = true
            }
            if let order {
                query.appendInterpolation(unescaped: "\(updatedValue ? "," : "") \"order\" = ")
                query.appendInterpolation(order)
                updatedValue = true
            }
            if let completed {
                query.appendInterpolation(unescaped: "\(updatedValue ? "," : "") \"completed\" = ")
                query.appendInterpolation(completed)
                updatedValue = true
            }
            query.appendInterpolation(unescaped: " WHERE id = ")
            query.appendInterpolation(id)
            if updatedValue == false {
                throw HBHTTPError(.badRequest)
            }

            // UPDATE query
            _ = try await connection.query(
                PostgresQuery(stringInterpolation: query), 
                logger: logger
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
