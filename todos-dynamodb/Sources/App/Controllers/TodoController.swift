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

import Foundation
import Hummingbird
import NIO
import SotoDynamoDB

extension UUID: LosslessStringConvertible {
    public init?(_ description: String) {
        self.init(uuidString: description)
    }
}

struct TodoController: Sendable {
    let tableName = "hummingbird-todos"
    let dynamoDB: DynamoDB

    init(dynamoDB: DynamoDB) {
        self.dynamoDB = dynamoDB
    }

    func addRoutes(to group: RouterGroup<some RequestContext>) {
        group
            .get(use: self.list)
            .post(use: self.create)
            .delete(use: self.deleteAll)
            .get(":id", use: self.get)
            .patch(":id", use: self.updateId)
            .delete(":id", use: self.deleteId)
    }

    @Sendable func list(_ request: Request, context: some RequestContext) async throws -> [Todo] {
        let input = DynamoDB.ScanInput(tableName: self.tableName)
        let response = try await self.dynamoDB.scan(input, type: Todo.self, logger: context.logger)
        return response.items ?? []
    }

    @Sendable func create(_ request: Request, context: some RequestContext) async throws -> EditedResponse<Todo> {
        var todo = try await request.decode(as: Todo.self, context: context)
        guard let host = request.head.authority else { throw HTTPError(.badRequest, message: "No host header") }
        todo.id = UUID()
        todo.completed = false
        todo.url = "http://\(host)/todos/\(todo.id!)"
        let input = DynamoDB.PutItemCodableInput(item: todo, tableName: self.tableName)
        _ = try await self.dynamoDB.putItem(input, logger: context.logger)
        return EditedResponse(status: .created, response: todo)
    }

    @Sendable func get(_ request: Request, context: some RequestContext) async throws -> Todo? {
        let id = try context.parameters.require("id")
        let input = DynamoDB.QueryInput(
            consistentRead: true,
            expressionAttributeValues: [":id": .s(id)],
            keyConditionExpression: "id = :id",
            tableName: self.tableName
        )
        let response = try await self.dynamoDB.query(input, type: Todo.self, logger: context.logger)
        return response.items?.first
    }

    @Sendable func updateId(_ request: Request, context: some RequestContext) async throws -> Todo {
        var todo = try await request.decode(as: EditTodo.self, context: context)
        todo.id = try context.parameters.require("id", as: UUID.self)
        let input = DynamoDB.UpdateItemCodableInput(
            conditionExpression: "attribute_exists(id)",
            key: ["id"],
            returnValues: .allNew,
            tableName: self.tableName,
            updateItem: todo
        )
        do {
            let response = try await self.dynamoDB.updateItem(input, logger: context.logger)
            guard let attributes = response.attributes else { throw HTTPError(.internalServerError) }
            return try DynamoDBDecoder().decode(Todo.self, from: attributes)
        } catch let error as DynamoDBErrorType where error == .conditionalCheckFailedException {
            throw HTTPError(.notFound)
        }
    }

    @Sendable func deleteAll(_ request: Request, context: some RequestContext) async throws -> HTTPResponse.Status {
        let scanInput = DynamoDB.ScanInput(tableName: self.tableName)
        let items = try await self.dynamoDB.scan(scanInput, logger: context.logger).items ?? []
        let requestItems: [DynamoDB.WriteRequest] = items.compactMap { item in
            item["id"].map { .init(deleteRequest: .init(key: ["id": $0])) }
        }
        guard requestItems.count > 0 else { return .ok }
        let writeInput = DynamoDB.BatchWriteItemInput(requestItems: [self.tableName: requestItems])
        _ = try await self.dynamoDB.batchWriteItem(writeInput, logger: context.logger)
        return .ok
    }

    @Sendable func deleteId(_ request: Request, context: some RequestContext) async throws -> HTTPResponse.Status {
        let id = try context.parameters.require("id")

        let input = DynamoDB.DeleteItemInput(
            conditionExpression: "attribute_exists(id)",
            key: ["id": .s(id)],
            tableName: self.tableName
        )
        do {
            _ = try await self.dynamoDB.deleteItem(input, logger: context.logger)
            return .ok
        } catch let error as DynamoDBErrorType where error == .conditionalCheckFailedException {
            throw HTTPError(.notFound)
        }
    }
}
