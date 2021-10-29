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

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
struct TodoController {
    let tableName = "hummingbird-todos"
    func addRoutes(to group: HBRouterGroup) {
        group
            .get(use: self.list)
            .post(options: .editResponse, use: self.create)
            .delete(use: self.deleteAll)
            .get(":id", use: self.get)
            .patch(":id", use: self.updateId)
            .delete(":id", use: self.deleteId)
    }

    func list(_ request: HBRequest) async throws -> [Todo] {
        let input = DynamoDB.ScanInput(tableName: self.tableName)
        let response = try await request.aws.dynamoDB.scan(input, type: Todo.self, logger: request.logger, on: request.eventLoop)
        return response.items ?? []
    }

    func create(_ request: HBRequest) async throws -> Todo {
        guard var todo = try? request.decode(as: Todo.self) else { throw HBHTTPError(.badRequest) }
        guard let host = request.headers["host"].first else { throw HBHTTPError(.badRequest, message: "No host header") }
        todo.id = UUID()
        todo.completed = false
        todo.url = "http://\(host)/todos/\(todo.id!)"
        let input = DynamoDB.PutItemCodableInput(item: todo, tableName: self.tableName)
        _ = try await request.aws.dynamoDB.putItem(input, logger: request.logger, on: request.eventLoop)
        request.response.status = .created
        return todo
    }

    func get(_ request: HBRequest) async throws -> Todo? {
        guard let id = request.parameters.get("id", as: String.self) else { throw HBHTTPError(.badRequest) }
        let input = DynamoDB.QueryInput(
            consistentRead: true,
            expressionAttributeValues: [":id": .s(id)],
            keyConditionExpression: "id = :id",
            tableName: self.tableName
        )
        let response = try await request.aws.dynamoDB.query(input, type: Todo.self, logger: request.logger, on: request.eventLoop)
        return response.items?.first
    }

    func updateId(_ request: HBRequest) async throws -> Todo {
        guard var todo = try? request.decode(as: EditTodo.self) else { throw HBHTTPError(.badRequest) }
        guard let id = request.parameters.get("id", as: UUID.self) else { throw HBHTTPError(.badRequest) }
        todo.id = id
        let input = DynamoDB.UpdateItemCodableInput(
            conditionExpression: "attribute_exists(id)",
            key: ["id"],
            returnValues: .allNew,
            tableName: self.tableName,
            updateItem: todo
        )
        do {
            let response = try await request.aws.dynamoDB.updateItem(input, logger: request.logger, on: request.eventLoop)
            guard let attributes = response.attributes else { throw HBHTTPError(.internalServerError) }
            return try DynamoDBDecoder().decode(Todo.self, from: attributes)
        } catch let error as DynamoDBErrorType where error == .conditionalCheckFailedException {
            throw HBHTTPError(.notFound)
        }
    }

    func deleteAll(_ request: HBRequest) async throws -> HTTPResponseStatus {
        let scanInput = DynamoDB.ScanInput(tableName: self.tableName)
        let items = try await request.aws.dynamoDB.scan(scanInput, logger: request.logger, on: request.eventLoop).items ?? []
        let requestItems: [DynamoDB.WriteRequest] = items.compactMap { item in
            item["id"].map { .init(deleteRequest: .init(key: ["id": $0])) }
        }
        guard requestItems.count > 0 else { return .ok }
        let writeInput = DynamoDB.BatchWriteItemInput(requestItems: [self.tableName: requestItems])
        _ = try await request.aws.dynamoDB.batchWriteItem(writeInput, logger: request.logger, on: request.eventLoop)
        return .ok
    }

    func deleteId(_ request: HBRequest) async throws -> HTTPResponseStatus {
        guard let id = request.parameters.get("id", as: String.self) else { throw HBHTTPError(.badRequest) }

        let input = DynamoDB.DeleteItemInput(
            conditionExpression: "attribute_exists(id)",
            key: ["id": .s(id)],
            tableName: self.tableName
        )
        do {
            _ = try await request.aws.dynamoDB.deleteItem(input, logger: request.logger, on: request.eventLoop)
            return .ok
        } catch let error as DynamoDBErrorType where error == .conditionalCheckFailedException {
            throw HBHTTPError(.notFound)
        }
    }
}
