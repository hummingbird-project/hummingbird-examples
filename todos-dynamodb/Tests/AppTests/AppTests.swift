@testable import App
import Hummingbird
import HummingbirdXCT
import XCTest

final class AppTests: XCTestCase {
    func createTodo(title: String, client: some HBXCTClientProtocol) async throws -> UUID {
        let json = "{\"title\": \"\(title)\"}"
        let todo = try await client.XCTExecute(
            uri: "/todos",
            method: .post,
            body: ByteBufferAllocator().buffer(string: json)
        ) { response in
            XCTAssertEqual(response.status, .created)
            let body = try XCTUnwrap(response.body)
            return try JSONDecoder().decode(Todo.self, from: body)
        }
        return try XCTUnwrap(todo.id)
    }

    func getTodo(id: UUID, client: some HBXCTClientProtocol) async throws -> Todo {
        return try await client.XCTExecute(
            uri: "/todos/\(id)",
            method: .get
        ) { response in
            XCTAssertEqual(response.status, .ok)
            let body = try XCTUnwrap(response.body)
            return try JSONDecoder().decode(Todo.self, from: body)
        }
    }

    func listTodos(client: some HBXCTClientProtocol) async throws -> [Todo] {
        return try await client.XCTExecute(
            uri: "/todos/",
            method: .get
        ) { response in
            XCTAssertEqual(response.status, .ok)
            let body = try XCTUnwrap(response.body)
            return try JSONDecoder().decode([Todo].self, from: body)
        }
    }

    func updateTodo(editedTodo: EditTodo, id: UUID, client: some HBXCTClientProtocol) async throws -> Todo {
        let buffer = try JSONEncoder().encodeAsByteBuffer(editedTodo, allocator: ByteBufferAllocator())
        return try await client.XCTExecute(
            uri: "/todos/\(id)",
            method: .patch,
            body: buffer
        ) { response in
            XCTAssertEqual(response.status, .ok)
            let body = try XCTUnwrap(response.body)
            return try JSONDecoder().decode(Todo.self, from: body)
        }
    }

    func deleteTodo(id: UUID, client: some HBXCTClientProtocol) async throws {
        try await client.XCTExecute(
            uri: "/todos/\(id)",
            method: .delete
        ) { response in
            XCTAssertEqual(response.status, .ok)
        }
    }

    func deleteAllTodos(client: some HBXCTClientProtocol) async throws {
        try await client.XCTExecute(
            uri: "/todos/",
            method: .delete
        ) { response in
            XCTAssertEqual(response.status, .ok)
        }
    }

    // MARK: Tests

    func testCreate() async throws {
        try XCTSkipIf(HBEnvironment().get("CI") != nil)

        let app = TodosApp(configuration: .init())
        try await app.test(.live) { client in
            let todoId = try await self.createTodo(title: "Add more tests", client: client)
            let todo = try await self.getTodo(id: todoId, client: client)
            XCTAssertEqual(todo.id, todoId)
            XCTAssertEqual(todo.title, "Add more tests")
        }
    }

    func testList() async throws {
        try XCTSkipIf(HBEnvironment().get("CI") != nil)

        let app = TodosApp(configuration: .init())
        try await app.test(.live) { client in
            let todoId = try await self.createTodo(title: "Test listing tests", client: client)
            let todos = try await self.listTodos(client: client)
            let todo = try XCTUnwrap(todos.first { $0.id == todoId })
            XCTAssertEqual(todo.id, todoId)
            XCTAssertEqual(todo.title, "Test listing tests")
        }
    }

    func testUpdate() async throws {
        try XCTSkipIf(HBEnvironment().get("CI") != nil)

        let app = TodosApp(configuration: .init())
        try await app.test(.live) { client in
            let todoId = try await self.createTodo(title: "Update tests", client: client)
            let updatedTodo = try await self.updateTodo(editedTodo: .init(completed: true), id: todoId, client: client)
            XCTAssertEqual(updatedTodo.id, todoId)
            XCTAssertEqual(updatedTodo.completed, true)
            let getTodo = try await self.getTodo(id: todoId, client: client)
            XCTAssertEqual(getTodo.id, todoId)
            XCTAssertEqual(getTodo.title, "Update tests")
            XCTAssertEqual(getTodo.completed, true)
        }
    }

    func testDelete() async throws {
        try XCTSkipIf(HBEnvironment().get("CI") != nil)

        let app = TodosApp(configuration: .init())
        try await app.test(.live) { client in
            let todoId = try await self.createTodo(title: "Delete tests", client: client)
            try await self.deleteTodo(id: todoId, client: client)
            let todos = try await self.listTodos(client: client)
            XCTAssertNil(todos.first { $0.id == todoId })
        }
    }

    func testDeleteAll() async throws {
        try XCTSkipIf(HBEnvironment().get("CI") != nil)

        let app = TodosApp(configuration: .init())
        try await app.test(.live) { client in
            _ = try await self.createTodo(title: "Delete all tests", client: client)
            try await self.deleteAllTodos(client: client)
            let todos = try await self.listTodos(client: client)
            XCTAssertEqual(todos.count, 0)
        }
    }
}
