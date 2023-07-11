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

struct TodoController {
    func addRoutes(to group: HBRouterGroup) {
        group
            .add(middleware: SessionAuthenticator())
            .add(middleware: IsAuthenticatedMiddleware(User.self))
            .get(use: self.list)
            .get(":id", use: self.get)
            .post(options: .editResponse, use: self.create)
            .delete(use: self.deleteAll)
            .patch(":id", use: self.update)
            .delete(":id", use: self.deleteId)
    }

    func list(_ request: HBRequest) async throws -> [Todo] {
        return try await Todo.query(on: request.db).all()
    }

    func create(_ request: HBRequest) async throws -> Todo {
        guard let todo = try? request.decode(as: Todo.self) else { throw HBHTTPError(.badRequest) }
        guard let host = request.headers["host"].first else { throw HBHTTPError(.badRequest, message: "No host header") }
        _ = try await todo.save(on: request.db)
        todo.completed = false
        todo.url = "http://\(host)/todos/\(todo.id!)"
        try await todo.update(on: request.db)
        request.response.status = .created
        return todo
    }

    func get(_ request: HBRequest) async throws -> Todo? {
        guard let id = request.parameters.get("id", as: UUID.self) else { throw HBHTTPError(.badRequest) }
        return try await Todo.find(id, on: request.db)
    }

    func update(_ request: HBRequest) async throws -> Todo {
        guard let id = request.parameters.get("id", as: UUID.self) else { throw HBHTTPError(.badRequest) }
        guard let newTodo = try? request.decode(as: EditTodo.self) else { throw HBHTTPError(.badRequest) }
        guard let todo = try await Todo.find(id, on: request.db) else { throw HBHTTPError(.notFound) }
        todo.update(from: newTodo)
        try await todo.update(on: request.db)
        return todo
    }

    func deleteAll(_ request: HBRequest) async throws -> HTTPResponseStatus {
        try await Todo.query(on: request.db)
            .delete()
        return .ok
    }

    func deleteId(_ request: HBRequest) async throws -> HTTPResponseStatus {
        guard let id = request.parameters.get("id", as: UUID.self) else { throw HBHTTPError(.badRequest) }
        guard let todo = try await Todo.find(id, on: request.db) else { throw HBHTTPError(.notFound) }
        try await todo.delete(on: request.db)
        return .ok
    }
}
