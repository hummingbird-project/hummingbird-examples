import Configuration
import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import Testing

@testable import App

private let reader = ConfigReader(providers: [
    InMemoryProvider(values: [
        "host": "127.0.0.1",
        "port": "0",
        "log.level": "trace",
        "db.inMemoryTesting": true,
    ])
])

@Suite
struct AppTests {
    struct CreateRequest: Encodable {
        let title: String
        let order: Int?
    }

    func create(title: String, order: Int? = nil, client: some TestClientProtocol) async throws -> Todo {
        let request = CreateRequest(title: title, order: order)
        let buffer = try JSONEncoder().encodeAsByteBuffer(request, allocator: ByteBufferAllocator())
        return try await client.execute(uri: "/todos", method: .post, body: buffer) { response in
            #expect(response.status == .created)
            return try JSONDecoder().decode(Todo.self, from: response.body)
        }
    }

    func get(id: UUID, client: some TestClientProtocol) async throws -> Todo? {
        try await client.execute(uri: "/todos/\(id)", method: .get) { response in
            // either the get request returned an 200 status or it didn't return a Todo
            #expect(response.status == .ok || response.body.readableBytes == 0)
            if response.body.readableBytes > 0 {
                return try JSONDecoder().decode(Todo.self, from: response.body)
            } else {
                return nil
            }
        }
    }

    func list(client: some TestClientProtocol) async throws -> [Todo] {
        try await client.execute(uri: "/todos", method: .get) { response in
            #expect(response.status == .ok)
            return try JSONDecoder().decode([Todo].self, from: response.body)
        }
    }

    struct UpdateRequest: Encodable {
        let title: String?
        let order: Int?
        let completed: Bool?
    }

    func patch(
        id: UUID,
        title: String? = nil,
        order: Int? = nil,
        completed: Bool? = nil,
        client: some TestClientProtocol
    ) async throws -> Todo? {
        let request = UpdateRequest(title: title, order: order, completed: completed)
        let buffer = try JSONEncoder().encodeAsByteBuffer(request, allocator: ByteBufferAllocator())
        return try await client.execute(uri: "/todos/\(id)", method: .patch, body: buffer) { response in
            #expect(response.status == .ok)
            if response.body.readableBytes > 0 {
                return try JSONDecoder().decode(Todo.self, from: response.body)
            } else {
                return nil
            }
        }
    }

    func delete(id: UUID, client: some TestClientProtocol) async throws -> HTTPResponse.Status {
        try await client.execute(uri: "/todos/\(id)", method: .delete) { response in
            response.status
        }
    }

    func deleteAll(client: some TestClientProtocol) async throws {
        try await client.execute(uri: "/todos", method: .delete) { _ in }
    }

    // MARK: Tests

    @Test func testCreate() async throws {
        let app = try await buildApplication(reader: reader)
        try await app.test(.router) { client in
            let todo = try await self.create(title: "My first todo", client: client)
            #expect(todo.title == "My first todo")
        }
    }

    @Test func testPatch() async throws {
        let app = try await buildApplication(reader: reader)
        try await app.test(.router) { client in
            // create todo
            let todo = try await self.create(title: "Deliver parcels to James", client: client)
            // rename it
            _ = try await self.patch(id: todo.id, title: "Deliver parcels to Claire", client: client)
            let editedTodo = try await self.get(id: todo.id, client: client)
            #expect(editedTodo?.title == "Deliver parcels to Claire")
            // set it to completed
            _ = try await self.patch(id: todo.id, completed: true, client: client)
            let editedTodo2 = try await self.get(id: todo.id, client: client)
            #expect(editedTodo2?.completed == true)
            // revert it
            _ = try await self.patch(id: todo.id, title: "Deliver parcels to James", completed: false, client: client)
            let editedTodo3 = try await self.get(id: todo.id, client: client)
            #expect(editedTodo3?.title == "Deliver parcels to James")
            #expect(editedTodo3?.completed == false)
        }
    }

    @Test func testAPI() async throws {
        let app = try await buildApplication(reader: reader)
        try await app.test(.router) { client in
            // create two todos
            let todo1 = try await self.create(title: "Wash my hair", client: client)
            let todo2 = try await self.create(title: "Brush my teeth", client: client)
            // get first todo
            let getTodo = try await self.get(id: todo1.id, client: client)
            #expect(getTodo == todo1)
            // patch second todo
            let optionalPatchedTodo = try await self.patch(id: todo2.id, completed: true, client: client)
            let patchedTodo = try #require(optionalPatchedTodo)
            #expect(patchedTodo.completed == true)
            #expect(patchedTodo.title == todo2.title)
            // get all todos and check first todo and patched second todo are in the list
            let todos = try await self.list(client: client)
            #expect(todos.firstIndex(of: todo1) != nil)
            #expect(todos.firstIndex(of: patchedTodo) != nil)
            // delete a todo and verify it has been deleted
            let status = try await self.delete(id: todo1.id, client: client)
            #expect(status == .ok)
            let deletedTodo = try await self.get(id: todo1.id, client: client)
            #expect(deletedTodo == nil)
            // delete all todos and verify there are none left
            try await self.deleteAll(client: client)
            let todos2 = try await self.list(client: client)
            #expect(todos2.count == 0)
        }
    }

    @Test func testDeletingTodoTwiceReturnsBadRequest() async throws {
        let app = try await buildApplication(reader: reader)
        try await app.test(.router) { client in
            let todo = try await self.create(title: "Delete me", client: client)
            let status1 = try await self.delete(id: todo.id, client: client)
            #expect(status1 == .ok)
            let status2 = try await self.delete(id: todo.id, client: client)
            #expect(status2 == .badRequest)
        }
    }

    @Test func testGettingTodoWithInvalidUUIDReturnsBadRequest() async throws {
        let app = try await buildApplication(reader: reader)
        try await app.test(.router) { client in
            // The get helper function doesnt allow me to supply random strings
            try await client.execute(uri: "/todos/NotAUUID", method: .get) { response in
                #expect(response.status == .badRequest)
            }
        }
    }

    @Test func test30ConcurrentlyCreatedTodosAreAllCreated() async throws {
        let app = try await buildApplication(reader: reader)
        try await app.test(.router) { client in
            let todos = try await withThrowingTaskGroup(of: Todo.self) { group in
                for count in 0..<30 {
                    group.addTask {
                        try await self.create(title: "Todo: \(count)", client: client)
                    }
                }
                var todos: [Todo] = []
                for try await todo in group {
                    todos.append(todo)
                }
                return todos
            }
            let todoList = try await self.list(client: client)
            for todo in todos {
                #expect(todoList.firstIndex(of: todo) != nil)
            }
        }
    }

    @Test func testUpdatingNonExistentTodoReturnsBadRequest() async throws {
        let app = try await buildApplication(reader: reader)
        try await app.test(.router) { client in
            // The patch helper function assumes it is going to work so we have to write our own here
            let request = UpdateRequest(title: "Update", order: nil, completed: nil)
            let buffer = try JSONEncoder().encodeAsByteBuffer(request, allocator: ByteBufferAllocator())
            return try await client.execute(uri: "/todos/\(UUID())", method: .patch, body: buffer) { response in
                #expect(response.status == .badRequest)
            }
        }
    }
}
