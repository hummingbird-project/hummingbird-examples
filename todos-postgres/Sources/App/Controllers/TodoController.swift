import Foundation
import Hummingbird
import PostgresNIO

struct TodoController {
    let connectionPoolGroup: HBConnectionPoolGroup<PostgresConnectionSource>
    let tableName = "todospostgres"

    @discardableResult func connection<NewValue>(for request: HBRequest, closure: @escaping (PSQLConnection) async throws -> NewValue) async throws -> NewValue {
        return try await connectionPoolGroup.lease(on: request.eventLoop, logger: request.logger, process: closure)
    }

    func addRoutes(to group: HBRouterGroup) {
        group
            .get(use: self.list)
            .get(":id", use: self.get)
            .post(options: .editResponse, use: self.create)
            .delete(use: self.deleteAll)
            .patch(":id", use: self.update)
            .delete(":id", use: self.deleteId)
    }

    func list(request: HBRequest) async throws -> [Todo] {
        let todos = try await self.connection(for: request) { connection -> [Todo] in
            let stream = try await connection.query(#"SELECT "id", "title", "order", "url", "completed" FROM todospostgres"#, logger: request.logger)
            var todos: [Todo] = []
            for try await (id, title, order, url, completed) in stream.decode((UUID, String, Int?, String, Bool?).self, context: .default) {
                let todo = Todo(id: id, title: title, order: order, url: url, completed: completed)
                todos.append(todo)
            }
            return todos
        }
        return todos
    }

    func get(request: HBRequest) async throws -> Todo? {
        let id = try request.parameters.require("id", as: UUID.self)
        return try await self.connection(for: request) { connection -> Todo? in
            let stream = try await connection.query("""
                SELECT "id", "title", "order", "url", "completed" FROM todospostgres WHERE "id" = \(id)
                """, 
                logger: request.logger
            )
            for try await (id, title, order, url, completed) in stream.decode((UUID, String, Int?, String, Bool?).self, context: .default) {
                let todo = Todo(id: id, title: title, order: order, url: url, completed: completed)
                return todo
            }
            return nil
        }
    }

    func create(request: HBRequest) async throws -> Todo {
        struct CreateTodo: Decodable {
            let title: String
            var order: Int?
        }
        guard let host = request.headers["host"].first else { throw HBHTTPError(.badRequest, message: "No host header") }
        let todo = try request.decode(as: CreateTodo.self)
        let id = UUID()
        let url = "http://\(host)/todos/\(id)"
        try await self.connection(for: request) { connection in 
            let query = try PSQLQuery(
                "INSERT INTO todospostgres (id, title, url, \"order\") VALUES ($1, $2, $3, $4);",
                id, todo.title, url, todo.order, context: .default
            )
            _ = try await connection.query(query, logger: request.logger)
        }
        request.response.status = .created
        return Todo(id: id, title: todo.title, order: todo.order, url: url)
    }

    func deleteAll(request: HBRequest) async throws -> HTTPResponseStatus {
        try await self.connection(for: request) { connection in
            _ = try await connection.query("DELETE FROM todospostgres;", logger: request.logger)
        }
        return .ok
    }

    func update(request: HBRequest) async throws -> HTTPResponseStatus {
        struct UpdateTodo: Decodable {
            var title: String?
            var order: Int?
            var completed: Bool?
        }
        let id = try request.parameters.require("id", as: UUID.self)
        let todo = try request.decode(as: UpdateTodo.self)
        try await self.connection(for: request) { connection in
            let psqlQuery = try PSQLQuery(
                #"UPDATE todospostgres SET "title" = $1, "order" = $2, "completed" = $3 WHERE id = $4"#,
                todo.title, todo.order, todo.completed, id, context: .default
            )
            _ = try await connection.query(psqlQuery, logger: request.logger)
        }
        return .ok
    }

    func deleteId(request: HBRequest) async throws -> HTTPResponseStatus {
        let id = try request.parameters.require("id", as: UUID.self)
        try await self.connection(for: request) { connection in
            _ = try await connection.query("DELETE FROM todospostgres WHERE id = \(id);", logger: request.logger)
        }
        return .ok
    }
}

extension UUID: LosslessStringConvertible {
    public init?(_ description: String) {
        self.init(uuidString: description)
    }
}
