import Foundation
import Hummingbird

struct TodoController<Repository: TodoRepository> {
    // Todo repository
    let repository: Repository

    // return todo endpoints
    var endpoints: RouteCollection<AppRequestContext> {
        return RouteCollection(context: AppRequestContext.self)
            .get(":id", use: self.get)
            .get(use: self.list)
            .post(use: self.create)
            .patch(":id", use: self.update)
            .delete(":id", use: self.delete)
            .delete(use: self.deleteAll)
    }

    /// Delete all todos entrypoint
    @Sendable func deleteAll(request: Request, context: some RequestContext) async throws -> HTTPResponse.Status {
        try await self.repository.deleteAll()
        return .ok
    }

    /// Delete todo entrypoint
    @Sendable func delete(request: Request, context: some RequestContext) async throws -> HTTPResponse.Status {
        let id = try context.parameters.require("id", as: UUID.self)
        if try await self.repository.delete(id: id) {
            return .ok
        } else {
            return .badRequest
        }
    }

    struct UpdateRequest: Decodable {
        let title: String?
        let order: Int?
        let completed: Bool?
    }

    /// Update todo entrypoint
    @Sendable func update(request: Request, context: some RequestContext) async throws -> Todo? {
        let id = try context.parameters.require("id", as: UUID.self)
        let request = try await request.decode(as: UpdateRequest.self, context: context)
        guard let todo = try await self.repository.update(
            id: id,
            title: request.title,
            order: request.order,
            completed: request.completed
        ) else {
            throw HTTPError(.badRequest)
        }
        return todo
    }

    /// Get todo entrypoint
    @Sendable func get(request: Request, context: some RequestContext) async throws -> Todo? {
        let id = try context.parameters.require("id", as: UUID.self)
        return try await self.repository.get(id: id)
    }

    /// Get list of todos entrypoint
    @Sendable func list(request: Request, context: some RequestContext) async throws -> [Todo] {
        return try await self.repository.list()
    }

    struct CreateRequest: Decodable {
        let title: String
        let order: Int?
    }

    /// Create todo entrypoint
    @Sendable func create(request: Request, context: some RequestContext) async throws -> EditedResponse<Todo> {
        let request = try await request.decode(as: CreateRequest.self, context: context)
        let todo = try await self.repository.create(title: request.title, order: request.order, urlPrefix: "http://localhost:8080/todos/")
        return EditedResponse(status: .created, response: todo)
    }
}
