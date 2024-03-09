import Foundation
import Hummingbird
import HummingbirdTesting
@testable import Todos
import XCTest

final class TodosTests: XCTestCase {
    struct TestArguments: AppArguments {
        let hostname = "127.0.0.1"
        let port = 8080
        let inMemoryTesting = true
    }

    struct CreateRequest: Encodable {
        let title: String
        let order: Int?
    }

    func create(title: String, order: Int? = nil, client: some HBTestClientProtocol) async throws -> Todo {
        let request = CreateRequest(title: title, order: order)
        let buffer = try JSONEncoder().encodeAsByteBuffer(request, allocator: ByteBufferAllocator())
        return try await client.execute(uri: "/todos", method: .post, body: buffer) { response in
            XCTAssertEqual(response.status, .created)
            return try JSONDecoder().decode(Todo.self, from: response.body)
        }
    }

    func get(id: UUID, client: some HBTestClientProtocol) async throws -> Todo? {
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

    func list(client: some HBTestClientProtocol) async throws -> [Todo] {
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

    func patch(id: UUID, title: String? = nil, order: Int? = nil, completed: Bool? = nil, client: some HBTestClientProtocol) async throws -> Todo? {
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

    func delete(id: UUID, client: some HBTestClientProtocol) async throws -> HTTPResponse.Status {
        try await client.execute(uri: "/todos/\(id)", method: .delete) { response in
            response.status
        }
    }

    func deleteAll(client: some HBTestClientProtocol) async throws {
        try await client.execute(uri: "/todos", method: .delete) { _ in }
    }

    // MARK: Tests

    func testCreate() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            let todo = try await self.create(title: "My first todo", client: client)
            XCTAssertEqual(todo.title, "My first todo")
        }
    }

    func testPatch() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            // create todo
            let todo = try await self.create(title: "Deliver parcels to James", client: client)
            // rename it
            _ = try await self.patch(id: todo.id, title: "Deliver parcels to Claire", client: client)
            let editedTodo = try await self.get(id: todo.id, client: client)
            XCTAssertEqual(editedTodo?.title, "Deliver parcels to Claire")
            // set it to completed
            _ = try await self.patch(id: todo.id, completed: true, client: client)
            let editedTodo2 = try await self.get(id: todo.id, client: client)
            XCTAssertEqual(editedTodo2?.completed, true)
            // revert it
            _ = try await self.patch(id: todo.id, title: "Deliver parcels to James", completed: false, client: client)
            let editedTodo3 = try await self.get(id: todo.id, client: client)
            XCTAssertEqual(editedTodo3?.title, "Deliver parcels to James")
            XCTAssertEqual(editedTodo3?.completed, false)
        }
    }

    func testAPI() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            // create two todos
            let todo1 = try await self.create(title: "Wash my hair", client: client)
            let todo2 = try await self.create(title: "Brush my teeth", client: client)
            // get first todo
            let getTodo = try await self.get(id: todo1.id, client: client)
            XCTAssertEqual(getTodo, todo1)
            // patch second todo
            let optionalPatchedTodo = try await self.patch(id: todo2.id, completed: true, client: client)
            let patchedTodo = try XCTUnwrap(optionalPatchedTodo)
            XCTAssertEqual(patchedTodo.completed, true)
            XCTAssertEqual(patchedTodo.title, todo2.title)
            // get all todos and check first todo and patched second todo are in the list
            let todos = try await self.list(client: client)
            XCTAssertNotNil(todos.firstIndex(of: todo1))
            XCTAssertNotNil(todos.firstIndex(of: patchedTodo))
            // delete a todo and verify it has been deleted
            let status = try await self.delete(id: todo1.id, client: client)
            XCTAssertEqual(status, .ok)
            let deletedTodo = try await self.get(id: todo1.id, client: client)
            XCTAssertNil(deletedTodo)
            // delete all todos and verify there are none left
            try await self.deleteAll(client: client)
            let todos2 = try await self.list(client: client)
            XCTAssertEqual(todos2.count, 0)
        }
    }

    func testDeletingTodoTwiceReturnsBadRequest() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            let todo = try await self.create(title: "Delete me", client: client)
            let status1 = try await self.delete(id: todo.id, client: client)
            XCTAssertEqual(status1, .ok)
            let status2 = try await self.delete(id: todo.id, client: client)
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
