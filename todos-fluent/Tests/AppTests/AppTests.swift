@testable import App
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

struct AppTests: Sendable {
    struct TestArguments: AppArguments {
        var hostname: String { "localhost" }
        var port: Int { 8080 }
        var migrate: Bool { true }
        var revert: Bool { false }
        var inMemoryDatabase: Bool { true }
    }

    enum TestError: Error {
        case unexpectedStatus(HTTPResponse.Status)
    }

    func createTodo(_ todo: CreateTodoRequest, client: some TestClientProtocol) async throws -> Todo {
        return try await client.execute(
            uri: "/api/todos",
            method: .post,
            headers: [.contentType: "application/json"],
            body: JSONEncoder().encodeAsByteBuffer(todo, allocator: ByteBufferAllocator())
        ) { response in
            guard response.status == .created else { throw TestError.unexpectedStatus(response.status) }
            return try JSONDecoder().decode(Todo.self, from: response.body)
        }
    }

    func getTodo(_ id: String, client: some TestClientProtocol) async throws -> Todo? {
        return try await client.execute(
            uri: "/api/todos/\(id)",
            method: .get
        ) { response in
            guard response.status == .ok else { throw TestError.unexpectedStatus(response.status) }
            return try JSONDecoder().decode(Todo.self, from: response.body)
        }
    }

    func deleteTodo(_ id: String, client: some TestClientProtocol) async throws {
        return try await client.execute(
            uri: "/api/todos/\(id)",
            method: .delete
        ) { response in
            guard response.status == .ok else { throw TestError.unexpectedStatus(response.status) }
        }
    }

    func editTodo(_ id: String, _ todo: EditTodoRequest, client: some TestClientProtocol) async throws -> Todo? {
        return try await client.execute(
            uri: "/api/todos/\(id)",
            method: .patch,
            headers: [.contentType: "application/json"],
            body: JSONEncoder().encodeAsByteBuffer(todo, allocator: ByteBufferAllocator())
        ) { response in
            guard response.status == .ok else { throw TestError.unexpectedStatus(response.status) }
            return try JSONDecoder().decode(Todo.self, from: response.body)
        }
    }

    // MARK: tests

    @Test func testCreateTodo() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            let todo = try await self.createTodo(.init(title: "Write more tests"), client: client)
            #expect(todo.title == "Write more tests")
        }
    }

    @Test func testGetTodo() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            let todo = try await self.createTodo(.init(title: "Write more tests"), client: client)
            let getTodo = try await self.getTodo(todo.id, client: client)
            #expect(getTodo?.title == "Write more tests")
        }
    }

    @Test func testDeleteTodo() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            let todo = try await self.createTodo(.init(title: "Write more tests"), client: client)
            try await self.deleteTodo(todo.id, client: client)

            do {
                _ = try await self.getTodo(todo.id, client: client)
            } catch TestError.unexpectedStatus(let status) {
                #expect(status == .noContent)
            } catch {
                Issue.record("Error: \(error)")
            }
        }
    }

    @Test func testEditTodo() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            let todo = try await self.createTodo(.init(title: "Write more tests"), client: client)
            _ = try await self.editTodo(todo.id, .init(title: "Written tests", completed: true), client: client)
            let editedTodo = try await self.getTodo(todo.id, client: client)

            #expect(editedTodo?.title == "Written tests")
            #expect(editedTodo?.completed == true)
        }
    }

    @Test func testUnauthorizedEditTodo() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            let todo = try await self.createTodo(.init(title: "Write more tests"), client: client)
            do {
                _ = try await self.editTodo(todo.id, .init(title: "Written tests", completed: true), client: client)
            } catch TestError.unexpectedStatus(let status) {
                #expect(status == .unauthorized)
            }
        }
    }
}

extension AppTests {
    struct CreateTodoRequest: Codable {
        let title: String
    }

    struct Todo: Codable {
        var id: String
        let title: String
        let completed: Bool
    }

    struct EditTodoRequest: Codable {
        var title: String?
        var order: Int?
        var completed: Bool?
    }
}
