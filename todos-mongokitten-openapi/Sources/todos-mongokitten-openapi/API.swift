@preconcurrency import MongoKitten
import OpenAPIRuntime
import TodosOpenAPI

/// The database model for a Todo
struct TodoModel: Codable {
    /// The TodoModel's unique identifier
    /// In MongoDB, `_id` is the primary key for a document
    /// While MongoDB supports any type as the primary key,
    /// `ObjectId` is the recommended type for primary keys
    let _id: ObjectId

    /// The checklist of items that are part of the Todo
    var items: [String]
}

extension Components.Schemas.Todo {
    /// Maps a `TodoModel` to a `Components.Schemas.Todo`
    /// This makes it easier to send models to the API
    init(model: TodoModel) {
        self.init(id: model._id.hexString, items: model.items)
    }
}

/// An implementation of the API protocol as specified in TodosOpenAPI/openapi.yaml
struct API: APIProtocol {
    let mongo: MongoDatabase

    /// The API route for creating a new Todo as specified TodosOpenAPI/openapi.yaml
    func createTodo(
        _ input: Operations.createTodo.Input
    ) async throws -> Operations.createTodo.Output {
        // Extract the JSON body from the request
        // Since the body of an OpenAPI request is an enum, we need to switch on it
        let items = switch input.body {
        case .json(let todo):
            todo.items
        }

        // Create a new TodoModel, generating a new primary key
        // And using the todo items from the request body
        let model = TodoModel(_id: ObjectId(), items: items)

        // Insert the model into the database.
        // This method will encode the model to BSON, MongoDB's native format
        try await mongo["todos"].insertEncoded(model)

        // Return the model to the client as JSON
        return .ok(.init(body: .json(.init(model: model))))
    }

    func getTodos(
        _ input: Operations.getTodos.Input
    ) async throws -> Operations.getTodos.Output {
        // Find all the TodoModels in the database
        let models = try await mongo["todos"].find()
            // Decode each entity from BSON to a TodoModel
            .decode(TodoModel.self)
            // Lazily map each TodoModel to a Components.Schemas.Todo
            .map(transform: Components.Schemas.Todo.init)
            // Drain the results into an array
            .drain()

        // Return the array of Components.Schemas.Todo to the client as JSON
        return .ok(.init(body: .json(models)))
    }

    func getTodo(
        _ input: Operations.getTodo.Input
    ) async throws -> Operations.getTodo.Output {
        // Extract the id from the path, and attempt to convert it to an ObjectId
        guard let id = ObjectId(input.path.id) else {
            // If the id is not a valid ObjectId, return a 400 Bad Request
            return .badRequest(.init(body: .json(.init(message: "Invalid id format"))))
        }

        // Find the TodoModel with the specified id
        // The primary key (id) is stored in the `_id` field in MongoDB
        // This call also decodes the BSON to a `TodoModel``
        guard let model = try await mongo["todos"].findOne(id == "_id", as: TodoModel.self) else {
            // If no TodoModel was found, return a 404 Not Found
            return .notFound(.init())
        }

        // If it _was_ found, send the model to the client as JSON
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

        // Create a new model, with the same id as the original
        let model = TodoModel(_id: id, items: items)

        // Update (overwrite) the model in the database
        guard try await self.mongo["todos"].updateEncoded(where: id == "_id", to: model).updatedCount == 1 else {
            // If the model was not updated, return a 404 Not Found
            // Since this means the _id does not exist in the database
            return .notFound(.init())
        }

        return .ok(.init(body: .json(.init(model: model))))
    }
}
