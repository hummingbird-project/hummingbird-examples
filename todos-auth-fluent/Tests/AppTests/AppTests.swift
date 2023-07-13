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

    enum TestError: Error {
        case unexpectedStatus(HTTPResponseStatus)
    }

    func testApplication(_ test: (HBApplication) throws -> Void) throws {
        let app = HBApplication(testing: .live)
        try app.configure(TestArguments())

        try app.XCTStart()
        defer { app.XCTStop() }
        try test(app)
    }

    func createUser(_ user: CreateUserRequest, app: HBApplication) throws -> CreateUserResponse {
        try app.XCTExecute(
            uri: "/api/users",
            method: .POST,
            headers: ["content-type": "application/json"],
            body: JSONEncoder().encodeAsByteBuffer(user, allocator: ByteBufferAllocator())
        ) { response in
            XCTAssertEqual(response.status, .created)
            let buffer = try XCTUnwrap(response.body)
            return try JSONDecoder().decode(CreateUserResponse.self, from: buffer)
        }
    }

    func login(username: String, password: String, app: HBApplication) throws -> String? {
        try app.XCTExecute(
            uri: "/api/users/login",
            method: .POST,
            headers: ["content-type": "application/json"],
            auth: .basic(username: username, password: password)
        ) { response in
            XCTAssertEqual(response.status, .ok)
            return response.headers["set-cookie"].first
        }
    }

    func urlEncodedLogin(username: String, password: String, app: HBApplication) throws -> String? {
        try app.XCTExecute(
            uri: "/login",
            method: .POST,
            headers: ["content-type": "application/x-www-form-urlencoded"],
            body: ByteBuffer(string: "email=\(username)&password=\(password)")
        ) { response in
            XCTAssertEqual(response.status, .found)
            return response.headers["set-cookie"].first
        }
    }

    func createTodo(_ todo: CreateTodoRequest, cookie: String? = nil, app: HBApplication) throws -> Todo {
        var headers: HTTPHeaders = ["content-type": "application/json"]
        if let cookie = cookie {
            headers.add(name: "cookie", value: cookie)
        }
        return try app.XCTExecute(
            uri: "/api/todos",
            method: .POST,
            headers: headers,
            body: JSONEncoder().encodeAsByteBuffer(todo, allocator: ByteBufferAllocator())
        ) { response in
            guard response.status == .created else { throw TestError.unexpectedStatus(response.status) }
            let buffer = try XCTUnwrap(response.body)
            return try JSONDecoder().decode(Todo.self, from: buffer)
        }
    }

    func getTodo(_ id: String, cookie: String? = nil, app: HBApplication) throws -> Todo? {
        return try app.XCTExecute(
            uri: "/api/todos/\(id)",
            method: .GET,
            headers: cookie.map { ["cookie": $0] } ?? [:]
        ) { response in
            guard response.status == .ok else { throw TestError.unexpectedStatus(response.status) }
            if let buffer = response.body {
                return try JSONDecoder().decode(Todo.self, from: buffer)
            }
            return nil
        }
    }

    func deleteTodo(_ id: String, cookie: String? = nil, app: HBApplication) throws {
        return try app.XCTExecute(
            uri: "/api/todos/\(id)",
            method: .DELETE,
            headers: cookie.map { ["cookie": $0] } ?? [:]
        ) { response in
            guard response.status == .ok else { throw TestError.unexpectedStatus(response.status) }
        }
    }

    func editTodo(_ id: String, _ todo: EditTodoRequest, cookie: String? = nil, app: HBApplication) throws -> Todo? {
        var headers: HTTPHeaders = ["content-type": "application/json"]
        if let cookie = cookie {
            headers.add(name: "cookie", value: cookie)
        }
        return try app.XCTExecute(
            uri: "/api/todos/\(id)",
            method: .PATCH,
            headers: headers,
            body: JSONEncoder().encodeAsByteBuffer(todo, allocator: ByteBufferAllocator())
        ) { response in
            guard response.status == .ok else { throw TestError.unexpectedStatus(response.status) }
            if let buffer = response.body {
                return try JSONDecoder().decode(Todo.self, from: buffer)
            }
            return nil
        }
    }

    // MARK: tests

    func testCreateUser() throws {
        try self.testApplication { app in
            _ = try self.createUser(.init(name: "Tom Jones", email: "t@jones.com", password: "password123"), app: app)
        }
    }

    func testLogin() throws {
        try self.testApplication { app in
            _ = try self.createUser(.init(name: "Tom Jones", email: "t@jones.com", password: "password123"), app: app)
            _ = try self.login(username: "t@jones.com", password: "password123", app: app)
        }
    }

    func testURLEncodedLogin() throws {
        try self.testApplication { app in
            _ = try self.createUser(.init(name: "Tom Jones", email: "t@jones.com", password: "password123"), app: app)
            let cookie = try self.urlEncodedLogin(username: "t@jones.com", password: "password123", app: app)
            XCTAssertNotNil(cookie)
        }
    }

    func testSession() throws {
        try self.testApplication { app in
            _ = try self.createUser(.init(name: "Tom Jones", email: "t@jones.com", password: "password123"), app: app)
            let cookie = try self.login(username: "t@jones.com", password: "password123", app: app)
            try app.XCTExecute(
                uri: "/api/users/",
                method: .GET,
                headers: cookie.map { ["cookie": $0] } ?? [:]
            ) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }

    func testCreateTodo() throws {
        try self.testApplication { app in
            _ = try self.createUser(.init(name: "Tom Jones", email: "t@jones.com", password: "password123"), app: app)
            let cookie = try self.login(username: "t@jones.com", password: "password123", app: app)
            let todo = try self.createTodo(.init(title: "Write more tests"), cookie: cookie, app: app)
            XCTAssertEqual(todo.title, "Write more tests")
        }
    }

    func testGetTodo() throws {
        try self.testApplication { app in
            _ = try self.createUser(.init(name: "Tom Jones", email: "t@jones.com", password: "password123"), app: app)
            let cookie = try self.login(username: "t@jones.com", password: "password123", app: app)
            let todo = try self.createTodo(.init(title: "Write more tests"), cookie: cookie, app: app)
            let getTodo = try self.getTodo(todo.id, cookie: cookie, app: app)
            XCTAssertEqual(getTodo?.title, "Write more tests")
        }
    }

    func testDeleteTodo() throws {
        try self.testApplication { app in
            _ = try self.createUser(.init(name: "Tom Jones", email: "t@jones.com", password: "password123"), app: app)
            let cookie = try self.login(username: "t@jones.com", password: "password123", app: app)
            let todo = try self.createTodo(.init(title: "Write more tests"), cookie: cookie, app: app)
            try self.deleteTodo(todo.id, cookie: cookie, app: app)

            XCTAssertThrowsError(_ = try self.getTodo(todo.id, cookie: cookie, app: app)) { error in
                switch error {
                case TestError.unexpectedStatus(let status):
                    XCTAssertEqual(status, .noContent)
                default:
                    XCTFail("Wrong error")
                }
            }
        }
    }

    func testEditTodo() throws {
        try self.testApplication { app in
            _ = try self.createUser(.init(name: "Tom Jones", email: "t@jones.com", password: "password123"), app: app)
            let cookie = try self.login(username: "t@jones.com", password: "password123", app: app)
            let todo = try self.createTodo(.init(title: "Write more tests"), cookie: cookie, app: app)
            _ = try self.editTodo(todo.id, .init(title: "Written tests", completed: true), cookie: cookie, app: app)
            let editedTodo = try self.getTodo(todo.id, cookie: cookie, app: app)

            XCTAssertEqual(editedTodo?.title, "Written tests")
            XCTAssertEqual(editedTodo?.completed, true)
        }
    }

    func testUnauthorizedEditTodo() throws {
        try self.testApplication { app in
            _ = try self.createUser(.init(name: "Tom Jones", email: "t@jones.com", password: "password123"), app: app)
            _ = try self.createUser(.init(name: "Lulu", email: "lu@lu.com", password: "admin"), app: app)
            let cookie = try self.login(username: "t@jones.com", password: "password123", app: app)
            let todo = try self.createTodo(.init(title: "Write more tests"), cookie: cookie, app: app)
            let cookie2 = try self.login(username: "lu@lu.com", password: "admin", app: app)
            XCTAssertThrowsError(
                _ = try self.editTodo(todo.id, .init(title: "Written tests", completed: true), cookie: cookie2, app: app)
            ) { error in
                switch error {
                case TestError.unexpectedStatus(let status):
                    XCTAssertEqual(status, .unauthorized)
                default:
                    XCTFail("Wrong error")
                }
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
