import App
import Hummingbird
import HummingbirdAuthXCT
import HummingbirdXCT
import XCTest

final class AppTests: XCTestCase {
    struct TestArguments: AppArguments {
        var migrate: Bool { true }
        var inMemoryDatabase: Bool { true }
    }

    struct Todo: Codable {
        var id: String?
        let title: String
    }

    func createTodo(_ todo: Todo, cookie: String? = nil, app: HBApplication) throws -> Todo {
        try app.XCTExecute(
            uri: "/todos",
            method: .POST,
            headers: cookie.map { ["cookie": $0] } ?? [:],
            body: JSONEncoder().encodeAsByteBuffer(todo, allocator: ByteBufferAllocator())
        ) { response in
            XCTAssertEqual(response.status, .created)
            let buffer = try XCTUnwrap(response.body)
            return try JSONDecoder().decode(Todo.self, from: buffer)
        }
    }

    struct User: Codable {
        var id: String?
        let name: String
        let password: String
    }

    struct UserResponse: Codable {
        var id: UUID
    }

    func createUser(_ user: User, app: HBApplication) throws -> UserResponse {
        try app.XCTExecute(
            uri: "/users",
            method: .POST,
            body: JSONEncoder().encodeAsByteBuffer(user, allocator: ByteBufferAllocator())
        ) { response in
            XCTAssertEqual(response.status, .created)
            let buffer = try XCTUnwrap(response.body)
            return try JSONDecoder().decode(UserResponse.self, from: buffer)
        }
    }

    func login(username: String, password: String, app: HBApplication) throws -> String? {
        try app.XCTExecute(
            uri: "/users/login",
            method: .POST,
            auth: .basic(username: username, password: password)
        ) { response in
            XCTAssertEqual(response.status, .ok)
            return response.headers["set-cookie"].first
        }
    }

    // MARK: tests

    func testCreateUser() throws {
        let app = HBApplication(testing: .live)
        try app.configure(TestArguments())

        try app.XCTStart()
        defer { app.XCTStop() }

        _ = try self.createUser(.init(name: "Tom Jones", password: "password123"), app: app)
    }

    func testLogin() throws {
        let app = HBApplication(testing: .live)
        try app.configure(TestArguments())

        try app.XCTStart()
        defer { app.XCTStop() }

        _ = try self.createUser(.init(name: "Tom Jones", password: "password123"), app: app)
        _ = try self.login(username: "Tom Jones", password: "password123", app: app)
    }

    func testSession() throws {
        let app = HBApplication(testing: .live)
        try app.configure(TestArguments())

        try app.XCTStart()
        defer { app.XCTStop() }

        _ = try self.createUser(.init(name: "Tom Jones", password: "password123"), app: app)
        let cookie = try self.login(username: "Tom Jones", password: "password123", app: app)
        try app.XCTExecute(
            uri: "/users/",
            method: .GET,
            headers: cookie.map { ["cookie": $0] } ?? [:]
        ) { response in
            XCTAssertEqual(response.status, .ok)
        }
    }

    func testCreateTodo() throws {
        let app = HBApplication(testing: .live)
        try app.configure(TestArguments())

        try app.XCTStart()
        defer { app.XCTStop() }

        _ = try self.createUser(.init(name: "Tom Jones", password: "password123"), app: app)
        let cookie = try self.login(username: "Tom Jones", password: "password123", app: app)
        let todo = try self.createTodo(.init(title: "Write more tests"), cookie: cookie, app: app)
        XCTAssertEqual(todo.title, "Write more tests")
    }
}
