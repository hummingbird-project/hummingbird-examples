import Foundation
import Hummingbird
import NIO
import SotoDynamoDB

extension UUID : LosslessStringConvertible {
    public init?(_ description: String) {
        self.init(uuidString: description)
    }
}


struct TodoController {
    let tableName = "hummingbird-todos"
    func addRoutes(to group: HBRouterGroup) {
        group
            .get(use: list)
            .post(use: create)
            .delete(use: deleteAll)
            .get(":id", use: get)
            .patch(":id", use: updateId)
            .delete(":id", use: deleteId)
    }
    
    func list(_ request: HBRequest) -> EventLoopFuture<[Todo]> {
        let input = DynamoDB.ScanInput(tableName: self.tableName)
        return request.aws.dynamoDB.scan(input, type: Todo.self, logger: request.logger, on: request.eventLoop)
            .map { $0.items ?? [] }
    }

    func create(_ request: HBRequest) -> EventLoopFuture<Todo> {
        guard var todo = try? request.decode(as: Todo.self) else { return request.failure(HBHTTPError(.badRequest)) }
        guard let host = request.headers["host"].first else { return request.failure(HBHTTPError(.badRequest, message: "No host header"))}
        let path = request.apiGatewayRequest.requestContext.path

        todo.id = UUID()
        todo.completed = false
        todo.url = "https://\(host)\(path)/\(todo.id!)"
        let input = DynamoDB.PutItemCodableInput(item: todo, tableName: self.tableName)
        return request.aws.dynamoDB.putItem(input, logger: request.logger, on: request.eventLoop)
            .map { _ in
                request.response.status = .created
                return todo
        }
    }

    func get(_ request: HBRequest) -> EventLoopFuture<Todo?> {
        guard let id = request.parameters.get("id", as: String.self) else { return request.failure(HBHTTPError(.badRequest)) }
        let input = DynamoDB.QueryInput(
            consistentRead: true,
            expressionAttributeValues: [":id": .s(id)],
            keyConditionExpression: "id = :id",
            tableName: self.tableName
        )
        return request.aws.dynamoDB.query(input, type: Todo.self, logger: request.logger, on: request.eventLoop)
            .map { $0.items?.first }
    }

    func updateId(_ request: HBRequest) -> EventLoopFuture<Todo> {
        guard var todo = try? request.decode(as: EditTodo.self) else { return request.failure(HBHTTPError(.badRequest)) }
        guard let id = request.parameters.get("id", as: UUID.self) else { return request.failure(HBHTTPError(.badRequest)) }
        todo.id = id
        let input = DynamoDB.UpdateItemCodableInput(
            conditionExpression: "attribute_exists(id)",
            key: ["id"],
            returnValues: .allNew,
            tableName: self.tableName,
            updateItem: todo
        )
        return request.aws.dynamoDB.updateItem(input, logger: request.logger, on: request.eventLoop)
            .flatMapErrorThrowing { error in
                if let error = error as? DynamoDBErrorType, error == .conditionalCheckFailedException {
                    throw HBHTTPError(.notFound)
                }
                throw error
            }
            .flatMapThrowing { response in
                guard let attributes = response.attributes else { throw HBHTTPError(.internalServerError) }
                return try DynamoDBDecoder().decode(Todo.self, from: attributes)
            }
    }

    func deleteAll(_ request: HBRequest) -> EventLoopFuture<HTTPResponseStatus> {
        let input = DynamoDB.ScanInput(tableName: self.tableName)
        return request.aws.dynamoDB.scan(input, logger: request.logger, on: request.eventLoop)
            .map { $0.items }
            .unwrap(orReplace: [])
            .flatMap { items -> EventLoopFuture<Void> in
                let requestItems: [DynamoDB.WriteRequest] = items.compactMap { item in
                    item["id"].map { .init(deleteRequest: .init(key: ["id": $0])) }
                }
                guard requestItems.count > 0 else { return request.success(()) }
                let input = DynamoDB.BatchWriteItemInput(requestItems: [self.tableName: requestItems])
                return request.aws.dynamoDB.batchWriteItem(input, logger: request.logger, on: request.eventLoop)
                    .map { _ in }
            }
            .map { _ in .ok }
    }

    func deleteId(_ request: HBRequest) -> EventLoopFuture<HTTPResponseStatus> {
        guard let id = request.parameters.get("id", as: String.self) else { return request.failure(HBHTTPError(.badRequest)) }

        let input = DynamoDB.DeleteItemInput(
            conditionExpression: "attribute_exists(id)",
            key: ["id": .s(id)],
            tableName: self.tableName
        )
        return request.aws.dynamoDB.deleteItem(input, logger: request.logger, on: request.eventLoop)
            .flatMapErrorThrowing { error in
                if let error = error as? DynamoDBErrorType, error == .conditionalCheckFailedException {
                    throw HBHTTPError(.notFound)
                }
                throw error
            }
            .map { _ in .ok }
    }
}
