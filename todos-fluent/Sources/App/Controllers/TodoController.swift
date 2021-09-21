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

struct TodoController {
    func addRoutes(to group: HBRouterGroup) {
        group
            .get(use: self.list)
            .get(":id", use: self.get)
            .post(options: .editResponse, use: self.create)
            .delete(use: self.deleteAll)
            .patch(use: self.update)
            .patch(":id", use: self.updateId)
            .delete(":id", use: self.deleteId)
    }

    func list(_ request: HBRequest) -> EventLoopFuture<[Todo]> {
        return Todo.query(on: request.db).all()
    }

    func create(_ request: HBRequest) -> EventLoopFuture<Todo> {
        guard let todo = try? request.decode(as: Todo.self) else { return request.failure(HBHTTPError(.badRequest)) }
        guard let host = request.headers["host"].first else { return request.failure(HBHTTPError(.badRequest, message: "No host header")) }
        return todo.save(on: request.db)
            .flatMap { _ in
                todo.completed = false
                todo.url = "http://\(host)/todos/\(todo.id!)"
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
