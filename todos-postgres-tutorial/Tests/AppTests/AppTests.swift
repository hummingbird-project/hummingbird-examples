import Hummingbird
import HummingbirdTesting
import Logging
import XCTest

@testable import App

final class AppTests: XCTestCase {
    struct TestArguments: AppArguments {
        let hostname = "127.0.0.1"
        let port = 8080
        let logLevel: Logger.Level? = nil
        let inMemoryTesting = true
    }

    struct CreateRequest: Encodable {
        let title: String
        let order: Int?
    }
 
    static func create(title: String, order: Int? = nil, client: some TestClientProtocol) async throws -> Todo {
        let request = CreateRequest(title: title, order: order)
        let buffer = try JSONEncoder().encodeAsByteBuffer(request, allocator: ByteBufferAllocator())
        return try await client.execute(uri: "/todos", method: .post, body: buffer) { response in
            XCTAssertEqual(response.status, .created)
            return try JSONDecoder().decode(Todo.self, from: response.body)
        }
    }

    static func get(id: UUID, client: some TestClientProtocol) async throws -> Todo? {
        try await client.execute(uri: "/todos/\(id)", method: .get) { response in
            // either the get request returned an 200 status or it didn't return a Todo
            XCTAssert(response.status == .ok || response.body.readableBytes == 0)
            if response.body.readableBytes > 0 {
                return try JSONDecoder().decode(Todo.self, from: response.body)
            } else {
                return nil
            }
        }
    }

    static func list(client: some TestClientProtocol) async throws -> [Todo] {
        try await client.execute(uri: "/todos", method: .get) { response in
            XCTAssertEqual(response.status, .ok)
            return try JSONDecoder().decode([Todo].self, from: response.body)
        }
    }

    struct UpdateRequest: Encodable {
        let title: String?
        let order: Int?
        let completed: Bool?
    }

    static func patch(id: UUID, title: String? = nil, order: Int? = nil, completed: Bool? = nil, client: some TestClientProtocol) async throws -> Todo? {
        let request = UpdateRequest(title: title, order: order, completed: completed)
        let buffer = try JSONEncoder().encodeAsByteBuffer(request, allocator: ByteBufferAllocator())
        return try await client.execute(uri: "/todos/\(id)", method: .patch, body: buffer) { response in
            XCTAssertEqual(response.status, .ok)
            if response.body.readableBytes > 0 {
                return try JSONDecoder().decode(Todo.self, from: response.body)
            } else {
                return nil
            }
        }
    }

    static func delete(id: UUID, client: some TestClientProtocol) async throws -> HTTPResponse.Status {
        try await client.execute(uri: "/todos/\(id)", method: .delete) { response in
            response.status
        }
    }

    static func deleteAll(client: some TestClientProtocol) async throws {
        try await client.execute(uri: "/todos", method: .delete) { _ in }
    }

    // MARK: Tests

    func testCreate() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            let todo = try await Self.create(title: "My first todo", client: client)
            XCTAssertEqual(todo.title, "My first todo")
        }
    }

    func testPatch() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            // create todo
            let todo = try await Self.create(title: "Deliver parcels to James", client: client)
            // rename it
            _ = try await Self.patch(id: todo.id, title: "Deliver parcels to Claire", client: client)
            let editedTodo = try await Self.get(id: todo.id, client: client)
            XCTAssertEqual(editedTodo?.title, "Deliver parcels to Claire")
            // set it to completed
            _ = try await Self.patch(id: todo.id, completed: true, client: client)
            let editedTodo2 = try await Self.get(id: todo.id, client: client)
            XCTAssertEqual(editedTodo2?.completed, true)
            // revert it
            _ = try await Self.patch(id: todo.id, title: "Deliver parcels to James", completed: false, client: client)
            let editedTodo3 = try await Self.get(id: todo.id, client: client)
            XCTAssertEqual(editedTodo3?.title, "Deliver parcels to James")
            XCTAssertEqual(editedTodo3?.completed, false)
        }
    }

    func testAPI() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            // create two todos
            let todo1 = try await Self.create(title: "Wash my hair", client: client)
            let todo2 = try await Self.create(title: "Brush my teeth", client: client)
            // get first todo
            let getTodo = try await Self.get(id: todo1.id, client: client)
            XCTAssertEqual(getTodo, todo1)
            // patch second todo
            let optionalPatchedTodo = try await Self.patch(id: todo2.id, completed: true, client: client)
            let patchedTodo = try XCTUnwrap(optionalPatchedTodo)
            XCTAssertEqual(patchedTodo.completed, true)
            XCTAssertEqual(patchedTodo.title, todo2.title)
            // get all todos and check first todo and patched second todo are in the list
            let todos = try await Self.list(client: client)
            XCTAssertNotNil(todos.firstIndex(of: todo1))
            XCTAssertNotNil(todos.firstIndex(of: patchedTodo))
            // delete a todo and verify it has been deleted
            let status = try await Self.delete(id: todo1.id, client: client)
            XCTAssertEqual(status, .ok)
            let deletedTodo = try await Self.get(id: todo1.id, client: client)
            XCTAssertNil(deletedTodo)
            // delete all todos and verify there are none left
            try await Self.deleteAll(client: client)
            let todos2 = try await Self.list(client: client)
            XCTAssertEqual(todos2.count, 0)
        }
    }

    func testDeletingTodoTwiceReturnsBadRequest() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            let todo = try await Self.create(title: "Delete me", client: client)
            let status1 = try await Self.delete(id: todo.id, client: client)
            XCTAssertEqual(status1, .ok)
            let status2 = try await Self.delete(id: todo.id, client: client)
            XCTAssertEqual(status2, .badRequest)
        }
    }

    func testGettingTodoWithInvalidUUIDReturnsBadRequest() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            // The get helper function doesnt allow me to supply random strings
            return try await client.execute(uri: "/todos/NotAUUID", method: .get) { response in
                XCTAssertEqual(response.status, .badRequest)
            }
        }
    }

    func test30ConcurrentlyCreatedTodosAreAllCreated() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            let todos = try await withThrowingTaskGroup(of: Todo.self) { group in
                for count in 0..<30 {
                    group.addTask {
                        try await Self.create(title: "Todo: \(count)", client: client)
                    }
                }
                var todos: [Todo] = []
                for try await todo in group {
                    todos.append(todo)
                }
                return todos
            }
            let todoList = try await Self.list(client: client)
            for todo in todos {
                XCTAssertNotNil(todoList.firstIndex(of: todo))
            }
        }
    }

    func testUpdatingNonExistentTodoReturnsBadRequest() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            // The patch helper function assumes it is going to work so we have to write our own here
            let request = UpdateRequest(title: "Update", order: nil, completed: nil)
            let buffer = try JSONEncoder().encodeAsByteBuffer(request, allocator: ByteBufferAllocator())
            return try await client.execute(uri: "/todos/\(UUID())", method: .patch, body: buffer) { response in
                XCTAssertEqual(response.status, .badRequest)
            }
        }
    }
}
