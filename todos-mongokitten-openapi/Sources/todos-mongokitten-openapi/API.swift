@preconcurrency import MongoKitten
import OpenAPIRuntime
import TodosOpenAPI

struct TodoModel: Codable {
    let _id: ObjectId
    let items: [String]
}

extension Components.Schemas.Todo {
    init(model: TodoModel) {
        self.init(id: model._id.hexString, items: model.items)
    }
}

struct API: APIProtocol {
    let mongo: MongoDatabase

    func createTodo(
        _ input: Operations.createTodo.Input
    ) async throws -> Operations.createTodo.Output {
        let items = switch input.body {
        case .json(let todo):
            todo.items
        }
        
        let model = TodoModel(_id: ObjectId(), items: items)
        try await mongo["todos"].insertEncoded(model)
        return .ok(.init(body: .json(.init(model: model))))
    }

    func getTodos(
        _ input: Operations.getTodos.Input
    ) async throws -> Operations.getTodos.Output {
        let models = try await mongo["todos"]
            .find()
            .decode(TodoModel.self)
            .map(transform: Components.Schemas.Todo.init)
            .drain()

        return .ok(.init(body: .json(models)))
    }

    func getTodo(
        _ input: Operations.getTodo.Input
    ) async throws -> Operations.getTodo.Output {
        guard let id = ObjectId(input.path.id) else {
            return .badRequest(.init(body: .json(.init(message: "Invalid id format"))))
        }

        guard let model = try await mongo["todos"].findOne("_id" == id, as: TodoModel.self) else {
            return .notFound(.init())
        }
        
        return .ok(.init(body: .json(.init(model: model))))
    }

    func updateTodo(
        _ input: Operations.updateTodo.Input
    ) async throws -> Operations.updateTodo.Output {
        guard let id = ObjectId(input.path.id) else {
            return .badRequest(.init(body: .json(.init(message: "Invalid id format"))))
        }

        let items = switch input.body {
        case .json(let todo):
            todo.items
        }
    
        let model = TodoModel(_id: id, items: items)
        guard try await mongo["todos"].updateEncoded(where: "_id" == id, to: model).updatedCount == 1 else {
            return .notFound(.init())
        }
        
        return .ok(.init(body: .json(.init(model: model))))
    }
}