//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AWSLambdaEvents
import Foundation
import Hummingbird
import HummingbirdLambda
import NIO
import SotoDynamoDB

struct TodoController {
    typealias Context = HBBasicLambdaRequestContext<APIGatewayRequest>

    let dynamoDB: DynamoDB
    let tableName = "hummingbird-todos"

    func addRoutes(to group: HBRouterGroup<Context>) {
        group
            .get(use: self.list)
            .post(use: self.create)
            .delete(use: self.deleteAll)
            .get("{id}", use: self.get)
            .patch("{id}", use: self.updateId)
            .delete("{id}", use: self.deleteId)
    }

    @Sendable func list(_ request: HBRequest, context: Context) async throws -> [Todo] {
        let input = DynamoDB.ScanInput(tableName: self.tableName)
        let scanResponse = try await self.dynamoDB.scan(input, type: Todo.self, logger: context.logger)
        return scanResponse.items ?? []
    }

    @Sendable func create(_ request: HBRequest, context: Context) async throws -> HBEditedResponse<Todo> {
        var todo = try await request.decode(as: Todo.self, context: context)
        guard let host = request.head.authority else { throw HBHTTPError(.badRequest, message: "No host header") }
        let path = context.event.requestContext.path

        todo.id = UUID()
        todo.completed = false
        todo.url = "https://\(host)\(path)/\(todo.id!)"
        let input = DynamoDB.PutItemCodableInput(item: todo, tableName: self.tableName)
        _ = try await self.dynamoDB.putItem(input, logger: context.logger)
        return HBEditedResponse(status: .created, response: todo)
    }

    @Sendable func get(_ request: HBRequest, context: Context) async throws -> Todo? {
        let id = try context.parameters.require("id", as: String.self)
        let input = DynamoDB.QueryInput(
            consistentRead: true,
            expressionAttributeValues: [":id": .s(id)],
            keyConditionExpression: "id = :id",
            tableName: self.tableName
        )
        let queryResponse = try await self.dynamoDB.query(input, type: Todo.self, logger: context.logger)
        return queryResponse.items?.first
    }

    @Sendable func updateId(_ request: HBRequest, context: Context) async throws -> Todo {
        var todo = try await request.decode(as: EditTodo.self, context: context)
        let id = try context.parameters.require("id", as: UUID.self)
        todo.id = id
        let input = DynamoDB.UpdateItemCodableInput(
            conditionExpression: "attribute_exists(id)",
            key: ["id"],
            returnValues: .allNew,
            tableName: self.tableName,
            updateItem: todo
        )
        do {
            let response = try await self.dynamoDB.updateItem(input, logger: context.logger)
            guard let attributes = response.attributes else { throw HBHTTPError(.internalServerError) }
            return try DynamoDBDecoder().decode(Todo.self, from: attributes)
        } catch let error as DynamoDBErrorType where error == .conditionalCheckFailedException {
            throw HBHTTPError(.notFound)
        }
    }

    @Sendable func deleteAll(_ request: HBRequest, context: Context) async throws -> HTTPResponse.Status {
        let input = DynamoDB.ScanInput(tableName: self.tableName)
        let items = try await self.dynamoDB.scan(input, logger: context.logger).items ?? []
        let requestItems: [DynamoDB.WriteRequest] = items.compactMap { item in
            item["id"].map { .init(deleteRequest: .init(key: ["id": $0])) }
        }
        guard requestItems.count > 0 else { return .ok }
        let batchWriteInput = DynamoDB.BatchWriteItemInput(requestItems: [self.tableName: requestItems])
        _ = try await self.dynamoDB.batchWriteItem(batchWriteInput, logger: context.logger)
        return .ok
    }

    @Sendable func deleteId(_ request: HBRequest, context: Context) async throws -> HTTPResponse.Status {
        let id = try context.parameters.require("id", as: String.self)

        let input = DynamoDB.DeleteItemInput(
            conditionExpression: "attribute_exists(id)",
            key: ["id": .s(id)],
            tableName: self.tableName
        )
        do {
            _ = try await self.dynamoDB.deleteItem(input, logger: context.logger)
            return .ok
        } catch let error as DynamoDBErrorType where error == .conditionalCheckFailedException {
            throw HBHTTPError(.notFound)
        }
    }
}
