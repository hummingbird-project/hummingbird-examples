@testable import App
import Hummingbird
import HummingbirdAuthXCT
import HummingbirdXCT
import XCTest

struct TestArguments: AppArguments {
    var migrate: Bool = true
    var inMemoryDatabase: Bool = true
}

final class AppTests: XCTestCase {
    func createUser<Return>(
        name: String,
        password: String,
        client: some HBXCTClientProtocol,
        _ callback: @escaping (HBXCTResponse) throws -> Return
    ) async throws -> Return {
        let request = CreateUserRequest(name: name, password: password)
        return try await client.XCTExecute(
            uri: "/user",
            method: .put,
            body: JSONEncoder().encodeAsByteBuffer(request, allocator: .init())
        ) {
            try callback($0)
        }
    }

    func login<Return>(
        name: String,
        password: String,
        client: some HBXCTClientProtocol,
        _ callback: @escaping (HBXCTResponse) throws -> Return
    ) async throws -> Return {
        return try await client.XCTExecute(
            uri: "/user/login",
            method: .post,
            auth: .basic(username: name, password: password)
        ) {
            try callback($0)
        }
    }

    func getCurrent<Return>(
        cookie: String?,
        client: some HBXCTClientProtocol,
        _ callback: @escaping (HBXCTResponse) throws -> Return
    ) async throws -> Return {
        return try await client.XCTExecute(
            uri: "/user",
            method: .get,
            headers: cookie.map { [.cookie: $0] } ?? [:]
        ) {
            try callback($0)
        }
    }

    func testCreateUser() async throws {
        let app = try await buildApplication(TestArguments(), configuration: .init())
        try await app.test(.live) { client in
            try await self.createUser(name: "adam", password: "test", client: client) { response in
                XCTAssertEqual(response.status, .ok)
            }
            try await self.createUser(name: "adam", password: "test", client: client) { response in
                XCTAssertEqual(response.status, .conflict)
            }
        }
    }

    func testLogin() async throws {
        let app = try await buildApplication(TestArguments(), configuration: .init())
        try await app.test(.live) { client in
            try await self.createUser(name: "adam", password: "testLogin", client: client) { response in
                XCTAssertEqual(response.status, .ok)
            }
            try await self.login(name: "adam", password: "testLogin", client: client) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }

    func testSession() async throws {
        let app = try await buildApplication(TestArguments(), configuration: .init())
        try await app.test(.live) { client in
            try await self.createUser(name: "john", password: "testSession", client: client) { response in
                XCTAssertEqual(response.status, .ok)
            }
            let cookie = try await self.login(name: "john", password: "testSession", client: client) { response in
                XCTAssertEqual(response.status, .ok)
                return try XCTUnwrap(response.headers[.setCookie])
            }
            try await self.getCurrent(cookie: cookie, client: client) { response in
                XCTAssertEqual(response.status, .ok)
                let body = try XCTUnwrap(response.body)
                let user = try JSONDecoder().decode(UserResponse.self, from: body)
                XCTAssertEqual(user.name, "john")
            }
            try await self.getCurrent(cookie: nil, client: client) { response in
                XCTAssertEqual(response.status, .unauthorized)
            }
        }
    }
}
