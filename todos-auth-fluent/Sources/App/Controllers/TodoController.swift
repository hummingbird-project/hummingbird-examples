//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import FluentKit
import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent
import NIO

/// CRUD routes for todos
struct TodoController {
    func addRoutes(to group: HBRouterGroup) {
        group
            .add(middleware: SessionAuthenticator())
            .add(middleware: IsAuthenticatedMiddleware(User.self))
            .get(use: self.list)
            .get(":id", use: self.get)
            .post(options: .editResponse, use: self.create)
            .patch(":id", use: self.update)
            .delete(":id", use: self.deleteId)
    }

    /// List all todos created by current user
    func list(_ request: HBRequest) async throws -> [Todo] {
        let user = try request.authRequire(User.self)
        return try await user.$todos.get(on: request.db)
    }

    struct CreateTodoRequest: HBResponseCodable {
        var title: String
    }

    /// Create new todo
    func create(_ request: HBRequest) async throws -> Todo {
        let user = try request.authRequire(User.self)
        guard let todoRequest = try? request.decode(as: CreateTodoRequest.self) else { throw HBHTTPError(.badRequest) }
        guard let host = request.headers["host"].first else { throw HBHTTPError(.badRequest, message: "No host header") }
        let todo = try Todo(title: todoRequest.title, ownerID: user.requireID())
        _ = try await todo.save(on: request.db)
        todo.completed = false
        todo.url = "http://\(host)/api/todos/\(todo.id!)"
        try await todo.update(on: request.db)
        request.response.status = .created
        return todo
    }

    /// Get todo
    func get(_ request: HBRequest) async throws -> Todo? {
        guard let id = request.parameters.get("id", as: UUID.self) else { throw HBHTTPError(.badRequest) }
        return try await Todo.query(on: request.db)
            .filter(\.$id == id)
            .with(\.$owner)
            .first()
    }

    struct EditTodoRequest: HBResponseCodable {
        var title: String?
        var completed: Bool?
    }

    /// Edit todo
    func update(_ request: HBRequest) async throws -> Todo {
        guard let id = request.parameters.get("id", as: UUID.self) else { throw HBHTTPError(.badRequest) }
        guard let editTodo = try? request.decode(as: EditTodoRequest.self) else { throw HBHTTPError(.badRequest) }
        guard let todo = try await Todo.query(on: request.db)
            .filter(\.$id == id)
            .with(\.$owner)
            .first()
        else {
            throw HBHTTPError(.notFound)
        }
        let user = try request.authRequire(User.self)
        guard todo.owner.id == user.id else { throw HBHTTPError(.unauthorized) }
        todo.update(title: editTodo.title, completed: editTodo.completed)
        try await todo.update(on: request.db)
        return todo
    }

    /// delete todo
    func deleteId(_ request: HBRequest) async throws -> HTTPResponseStatus {
        guard let id = request.parameters.get("id", as: UUID.self) else { throw HBHTTPError(.badRequest) }
        guard let todo = try await Todo.query(on: request.db)
            .filter(\.$id == id)
            .with(\.$owner)
            .first()
        else {
            throw HBHTTPError(.notFound)
        }
        let user = try request.authRequire(User.self)
        guard todo.owner.id == user.id else { throw HBHTTPError(.unauthorized) }
        try await todo.delete(on: request.db)
        return .ok
    }
}
