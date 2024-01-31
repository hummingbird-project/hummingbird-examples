@testable import App
import Hummingbird
import HummingbirdAuthXCT
import HummingbirdXCT
import XCTest

final class AppTests: XCTestCase {
    struct TestArguments: AppArguments {
        var hostname: String { "localhost" }
        var port: Int { 8080 }
        var migrate: Bool { true }
        var inMemoryDatabase: Bool { true }
    }

    enum TestError: Error {
        case unexpectedStatus(HTTPResponse.Status)
    }

    func createUser(_ user: CreateUserRequest, client: some HBXCTClientProtocol) async throws -> CreateUserResponse {
        try await client.XCTExecute(
            uri: "/api/users",
            method: .post,
            headers: [.contentType: "application/json"],
            body: JSONEncoder().encodeAsByteBuffer(user, allocator: ByteBufferAllocator())
        ) { response in
            XCTAssertEqual(response.status, .created)
            return try JSONDecoder().decode(CreateUserResponse.self, from: response.body)
        }
    }

    func login(username: String, password: String, client: some HBXCTClientProtocol) async throws -> String? {
        try await client.XCTExecute(
            uri: "/api/users/login",
            method: .post,
            headers: [.contentType: "application/json"],
            auth: .basic(username: username, password: password)
        ) { response in
            XCTAssertEqual(response.status, .ok)
            return response.headers[.setCookie]
        }
    }

    func urlEncodedLogin(username: String, password: String, client: some HBXCTClientProtocol) async throws -> String? {
        try await client.XCTExecute(
            uri: "/login",
            method: .post,
            headers: [.contentType: "application/x-www-form-urlencoded"],
            body: ByteBuffer(string: "email=\(username)&password=\(password)")
        ) { response in
            XCTAssertEqual(response.status, .found)
            return response.headers[.setCookie]
        }
    }

    func createTodo(_ todo: CreateTodoRequest, cookie: String? = nil, client: some HBXCTClientProtocol) async throws -> Todo {
        var headers: HTTPFields = [.contentType: "application/json"]
        if let cookie = cookie {
            headers[.cookie] = cookie
        }
        return try await client.XCTExecute(
            uri: "/api/todos",
            method: .post,
            headers: headers,
            body: JSONEncoder().encodeAsByteBuffer(todo, allocator: ByteBufferAllocator())
        ) { response in
            guard response.status == .created else { throw TestError.unexpectedStatus(response.status) }
            let buffer = try XCTUnwrap(response.body)
            return try JSONDecoder().decode(Todo.self, from: buffer)
        }
    }

    func getTodo(_ id: String, cookie: String? = nil, client: some HBXCTClientProtocol) async throws -> Todo? {
        return try await client.XCTExecute(
            uri: "/api/todos/\(id)",
            method: .get,
            headers: cookie.map { [.cookie: $0] } ?? [:]
        ) { response in
            guard response.status == .ok else { throw TestError.unexpectedStatus(response.status) }
            return try JSONDecoder().decode(Todo.self, from: response.body)
        }
    }

    func deleteTodo(_ id: String, cookie: String? = nil, client: some HBXCTClientProtocol) async throws {
        return try await client.XCTExecute(
            uri: "/api/todos/\(id)",
            method: .delete,
            headers: cookie.map { [.cookie: $0] } ?? [:]
        ) { response in
            guard response.status == .ok else { throw TestError.unexpectedStatus(response.status) }
        }
    }

    func editTodo(_ id: String, _ todo: EditTodoRequest, cookie: String? = nil, client: some HBXCTClientProtocol) async throws -> Todo? {
        var headers: HTTPFields = [.contentType: "application/json"]
        if let cookie = cookie {
            headers[.cookie] = cookie
        }
        return try await client.XCTExecute(
            uri: "/api/todos/\(id)",
            method: .patch,
            headers: headers,
            body: JSONEncoder().encodeAsByteBuffer(todo, allocator: ByteBufferAllocator())
        ) { response in
            guard response.status == .ok else { throw TestError.unexpectedStatus(response.status) }
            return try JSONDecoder().decode(Todo.self, from: response.body)
        }
    }

    // MARK: tests

    func testCreateUser() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            _ = try await self.createUser(.init(name: "Tom Jones", email: "t@jones.com", password: "password123"), client: client)
        }
    }

    func testLogin() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            _ = try await self.createUser(.init(name: "Tom Jones", email: "t@jones.com", password: "password123"), client: client)
            _ = try await self.login(username: "t@jones.com", password: "password123", client: client)
        }
    }

    func testURLEncodedLogin() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            _ = try await self.createUser(.init(name: "Tom Jones", email: "t@jones.com", password: "password123"), client: client)
            let cookie = try await self.urlEncodedLogin(username: "t@jones.com", password: "password123", client: client)
            XCTAssertNotNil(cookie)
        }
    }

    func testSession() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            _ = try await self.createUser(.init(name: "Tom Jones", email: "t@jones.com", password: "password123"), client: client)
            let cookie = try await self.login(username: "t@jones.com", password: "password123", client: client)
            try await client.XCTExecute(
                uri: "/api/users/",
                method: .get,
                headers: cookie.map { [.cookie: $0] } ?? [:]
            ) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }

    func testCreateTodo() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            _ = try await self.createUser(.init(name: "Tom Jones", email: "t@jones.com", password: "password123"), client: client)
            let cookie = try await self.login(username: "t@jones.com", password: "password123", client: client)
            let todo = try await self.createTodo(.init(title: "Write more tests"), cookie: cookie, client: client)
            XCTAssertEqual(todo.title, "Write more tests")
        }
    }

    func testGetTodo() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            _ = try await self.createUser(.init(name: "Tom Jones", email: "t@jones.com", password: "password123"), client: client)
            let cookie = try await self.login(username: "t@jones.com", password: "password123", client: client)
            let todo = try await self.createTodo(.init(title: "Write more tests"), cookie: cookie, client: client)
            let getTodo = try await self.getTodo(todo.id, cookie: cookie, client: client)
            XCTAssertEqual(getTodo?.title, "Write more tests")
        }
    }

    func testDeleteTodo() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            _ = try await self.createUser(.init(name: "Tom Jones", email: "t@jones.com", password: "password123"), client: client)
            let cookie = try await self.login(username: "t@jones.com", password: "password123", client: client)
            let todo = try await self.createTodo(.init(title: "Write more tests"), cookie: cookie, client: client)
            try await self.deleteTodo(todo.id, cookie: cookie, client: client)

            do {
                _ = try await self.getTodo(todo.id, cookie: cookie, client: client)
            } catch TestError.unexpectedStatus(let status) {
                XCTAssertEqual(status, .noContent)
            } catch {
                XCTFail("Error: \(error)")
            }
        }
    }

    func testEditTodo() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            _ = try await self.createUser(.init(name: "Tom Jones", email: "t@jones.com", password: "password123"), client: client)
            let cookie = try await self.login(username: "t@jones.com", password: "password123", client: client)
            let todo = try await self.createTodo(.init(title: "Write more tests"), cookie: cookie, client: client)
            _ = try await self.editTodo(todo.id, .init(title: "Written tests", completed: true), cookie: cookie, client: client)
            let editedTodo = try await self.getTodo(todo.id, cookie: cookie, client: client)

            XCTAssertEqual(editedTodo?.title, "Written tests")
            XCTAssertEqual(editedTodo?.completed, true)
        }
    }

    func testUnauthorizedEditTodo() async throws {
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            _ = try await self.createUser(.init(name: "Tom Jones", email: "t@jones.com", password: "password123"), client: client)
            _ = try await self.createUser(.init(name: "Lulu", email: "lu@lu.com", password: "admin"), client: client)
            let cookie = try await self.login(username: "t@jones.com", password: "password123", client: client)
            let todo = try await self.createTodo(.init(title: "Write more tests"), cookie: cookie, client: client)
            let cookie2 = try await self.login(username: "lu@lu.com", password: "admin", client: client)
            do {
                _ = try await self.editTodo(todo.id, .init(title: "Written tests", completed: true), cookie: cookie2, client: client)
            } catch TestError.unexpectedStatus(let status) {
                XCTAssertEqual(status, .unauthorized)
            }
        }
    }
}

extension AppTests {
    struct CreateUserRequest: Codable {
        let name: String
        let email: String
        let password: String
    }

    struct CreateUserResponse: Codable {
        var id: UUID
    }

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
