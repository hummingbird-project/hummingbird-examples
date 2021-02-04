import Foundation
import Hummingbird
import HummingbirdFluent
import FluentKit
import NIO

struct TodoController {
    func addRoutes(to group: HBRouterGroup) {
        group
            .get(use: list)
            .get(":id", use: get)
            .post(use: create)
            .delete(use: deleteAll)
            .patch(use: update)
            .patch(":id", use: updateId)
            .delete(":id", use: deleteId)
    }
    
    func list(_ request: HBRequest) -> EventLoopFuture<[Todo]> {
        return Todo.query(on: request.db).all()
    }

    func create(_ request: HBRequest) -> EventLoopFuture<Todo> {
        guard let todo = try? request.decode(as: Todo.self) else { return request.failure(HBHTTPError(.badRequest)) }
        return todo.save(on: request.db)
            .flatMap { _ in
                todo.completed = false
                todo.url = "http://dev.opticalaberration.com:8080/todos/\(todo.id!)"
                return todo.update(on: request.db)
            }
            .map { request.response.status = .created; return todo }
    }

    func get(_ request: HBRequest) -> EventLoopFuture<Todo?> {
        guard let id = request.parameters.get("id", as: UUID.self) else { return request.failure(HBHTTPError(.badRequest)) }
        return Todo.find(id, on: request.db)
    }

    func update(_ request: HBRequest) -> EventLoopFuture<Todo> {
        guard let newTodo = try? request.decode(as: Todo.self) else { return request.failure(HBHTTPError(.badRequest)) }
        return Todo.query(on: request.db)
            .filter(\.$title == "Test")
            .first()
            .unwrap(orError: HBHTTPError(.notFound))
            .flatMap { todo -> EventLoopFuture<Todo> in
                todo.update(from: newTodo)
                return todo.update(on: request.db).map { todo }
            }
    }

    func updateId(_ request: HBRequest) -> EventLoopFuture<Todo> {
        guard let id = request.parameters.get("id", as: UUID.self) else { return request.failure(HBHTTPError(.badRequest)) }
        guard let newTodo = try? request.decode(as: EditTodo.self) else { return request.failure(HBHTTPError(.badRequest)) }
        return Todo.find(id, on: request.db)
            .unwrap(orError: HBHTTPError(.notFound))
            .flatMap { todo -> EventLoopFuture<Todo> in
                todo.update(from: newTodo)
                return todo.update(on: request.db).map { todo }
            }
    }

    func deleteAll(_ request: HBRequest) -> EventLoopFuture<HTTPResponseStatus> {
        return Todo.query(on: request.db)
            .delete()
            .transform(to: .ok)
    }

    func deleteId(_ request: HBRequest) -> EventLoopFuture<HTTPResponseStatus> {
        guard let id = request.parameters.get("id", as: UUID.self) else { return request.failure(HBHTTPError(.badRequest)) }
        return Todo.find(id, on: request.db)
            .unwrap(orError: HBHTTPError(.notFound))
            .flatMap { todo in
                todo.delete(on: request.db)
            }
            .transform(to: .ok)
    }
}
