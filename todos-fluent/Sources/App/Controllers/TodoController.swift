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
import HummingbirdFluent
import NIO

struct TodoController<Context: RequestContext> {
    let fluent: Fluent

    func addRoutes(to group: RouterGroup<Context>) {
        group
            .get(use: self.list)
            .get(":id", use: self.get)
            .post(use: self.create)
            .patch(":id", use: self.update)
            .delete(":id", use: self.deleteId)
    }

    @Sendable func list(_ request: Request, context: Context) async throws -> [Todo] {
        try await Todo.query(on: self.fluent.db()).all()
    }

    struct CreateTodoRequest: ResponseCodable {
        var title: String
    }

    /// Create new todo
    @Sendable func create(_ request: Request, context: Context) async throws -> EditedResponse<Todo> {
        let todoRequest = try await request.decode(as: CreateTodoRequest.self, context: context)
        guard let host = request.head.authority else { throw HTTPError(.badRequest, message: "No host header") }
        let todo = try Todo(title: todoRequest.title)
        let db = self.fluent.db()
        _ = try await todo.save(on: db)
        todo.completed = false
        todo.url = "http://\(host)/api/todos/\(todo.id!)"
        try await todo.update(on: db)
        return .init(status: .created, response: todo)
    }

    /// Get todo
    @Sendable func get(_ request: Request, context: Context) async throws -> Todo? {
        let id = try context.parameters.require("id", as: UUID.self)
        return try await Todo.query(on: self.fluent.db())
            .filter(\.$id == id)
            .first()
    }

    struct EditTodoRequest: ResponseCodable {
        var title: String?
        var completed: Bool?
    }

    /// Edit todo
    @Sendable func update(_ request: Request, context: Context) async throws -> Todo {
        let id = try context.parameters.require("id", as: UUID.self)
        let editTodo = try await request.decode(as: EditTodoRequest.self, context: context)
        let db = self.fluent.db()
        guard let todo = try await Todo.query(on: db)
            .filter(\.$id == id)
            .first()
        else {
            throw HTTPError(.notFound)
        }
        todo.update(title: editTodo.title, completed: editTodo.completed)
        try await todo.update(on: db)
        return todo
    }

    /// delete todo
    @Sendable func deleteId(_ request: Request, context: Context) async throws -> HTTPResponse.Status {
        let id = try context.parameters.require("id", as: UUID.self)
        let db = self.fluent.db()
        guard let todo = try await Todo.query(on: db)
            .filter(\.$id == id)
            .first()
        else {
            throw HTTPError(.notFound)
        }
        try await todo.delete(on: db)
        return .ok
    }
}
