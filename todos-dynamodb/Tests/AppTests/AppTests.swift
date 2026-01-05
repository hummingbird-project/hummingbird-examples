import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import App

@Suite(
    "TODOs DynamoDB tests",
    .disabled(if: ProcessInfo.processInfo.environment["CI"] != nil, "Tests disabled in CI")
)
struct AppTests {
    func createTodo(title: String, client: some TestClientProtocol) async throws -> UUID {
        let json = "{\"title\": \"\(title)\"}"
        let todo = try await client.execute(
            uri: "/todos",
            method: .post,
            body: ByteBufferAllocator().buffer(string: json)
        ) { response in
            #expect(response.status == .created)
            return try JSONDecoder().decode(Todo.self, from: response.body)
        }
        return try #require(todo.id)
    }

    func getTodo(id: UUID, client: some TestClientProtocol) async throws -> Todo {
        try await client.execute(
            uri: "/todos/\(id)",
            method: .get
        ) { response in
            #expect(response.status == .ok)
            return try JSONDecoder().decode(Todo.self, from: response.body)
        }
    }

    func listTodos(client: some TestClientProtocol) async throws -> [Todo] {
        try await client.execute(
            uri: "/todos/",
            method: .get
        ) { response in
            #expect(response.status == .ok)
            return try JSONDecoder().decode([Todo].self, from: response.body)
        }
    }

    func updateTodo(editedTodo: EditTodo, id: UUID, client: some TestClientProtocol) async throws -> Todo {
        let buffer = try JSONEncoder().encodeAsByteBuffer(editedTodo, allocator: ByteBufferAllocator())
        return try await client.execute(
            uri: "/todos/\(id)",
            method: .patch,
            body: buffer
        ) { response in
            #expect(response.status == .ok)
            return try JSONDecoder().decode(Todo.self, from: response.body)
        }
    }

    func deleteTodo(id: UUID, client: some TestClientProtocol) async throws {
        try await client.execute(
            uri: "/todos/\(id)",
            method: .delete
        ) { response in
            #expect(response.status == .ok)
        }
    }

    func deleteAllTodos(client: some TestClientProtocol) async throws {
        try await client.execute(
            uri: "/todos/",
            method: .delete
        ) { response in
            #expect(response.status == .ok)
        }
    }

    // MARK: Tests

    @Test func testCreate() async throws {
        let app = TodosApp(configuration: .init())
        try await app.test(.live) { client in
            let todoId = try await self.createTodo(title: "Add more tests", client: client)
            let todo = try await self.getTodo(id: todoId, client: client)
            #expect(todo.id == todoId)
            #expect(todo.title == "Add more tests")
        }
    }

    @Test func testList() async throws {
        let app = TodosApp(configuration: .init())
        try await app.test(.live) { client in
            let todoId = try await self.createTodo(title: "Test listing tests", client: client)
            let todos = try await self.listTodos(client: client)
            let todo = try #require(todos.first { $0.id == todoId })
            #expect(todo.id == todoId)
            #expect(todo.title == "Test listing tests")
        }
    }

    @Test func testUpdate() async throws {
        let app = TodosApp(configuration: .init())
        try await app.test(.live) { client in
            let todoId = try await self.createTodo(title: "Update tests", client: client)
            let updatedTodo = try await self.updateTodo(editedTodo: .init(completed: true), id: todoId, client: client)
            #expect(updatedTodo.id == todoId)
            #expect(updatedTodo.completed == true)
            let getTodo = try await self.getTodo(id: todoId, client: client)
            #expect(getTodo.id == todoId)
            #expect(getTodo.title == "Update tests")
            #expect(getTodo.completed == true)
        }
    }

    @Test func testDelete() async throws {
        let app = TodosApp(configuration: .init())
        try await app.test(.live) { client in
            let todoId = try await self.createTodo(title: "Delete tests", client: client)
            try await self.deleteTodo(id: todoId, client: client)
            let todos = try await self.listTodos(client: client)
            #expect(todos.first { $0.id == todoId } == nil)
        }
    }

    @Test func testDeleteAll() async throws {
        let app = TodosApp(configuration: .init())
        try await app.test(.live) { client in
            _ = try await self.createTodo(title: "Delete all tests", client: client)
            try await self.deleteAllTodos(client: client)
            let todos = try await self.listTodos(client: client)
            #expect(todos.count == 0)
        }
    }
}
