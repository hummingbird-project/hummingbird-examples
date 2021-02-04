import Foundation
import Hummingbird
import HummingbirdFluent
import NIO

struct TodoController {
    func addRoutes(to group: HBRouterGroup) {
        group
            .get(use: list)
            .post(use: create)
            .delete(use: deleteAll)
            .get(":id", use: get)
            .put(":id", use: update)
    }
    
    func list(_ request: HBRequest) -> EventLoopFuture<[Todo]> {
        return Todo.query(on: request.db).all()
    }

    func create(_ request: HBRequest) -> EventLoopFuture<Todo> {
        guard let todo = try? request.decode(as: Todo.self) else { return request.failure(HBHTTPError(.badRequest)) }
        return todo.save(on: request.db).map { request.response.status = .created; return todo }
    }

    func get(_ request: HBRequest) -> EventLoopFuture<Todo?> {
        guard let id = request.parameters.get("id", as: UUID.self) else { return request.failure(HBHTTPError(.badRequest)) }
        return Todo.find(id, on: request.db)
    }

    func update(_ request: HBRequest) -> EventLoopFuture<Todo> {
        guard let todo = try? request.decode(as: Todo.self) else { return request.failure(HBHTTPError(.badRequest)) }
        guard let id = request.parameters.get("id", as: UUID.self) else { return request.failure(HBHTTPError(.badRequest)) }
        return Todo.find(id, on: request.db)
            .unwrap(orError: HBHTTPError(.notFound))
            .flatMap { dbEntry -> EventLoopFuture<Void> in
                dbEntry.title = todo.title
                return dbEntry.update(on: request.db)
            }
            .transform(to: todo)
    }

    func deleteAll(_ request: HBRequest) -> EventLoopFuture<HTTPResponseStatus> {
        return Todo.query(on: request.db).all()
            .flatMap { $0.delete(on: request.db) }
            .transform(to: .ok)
    }
}
