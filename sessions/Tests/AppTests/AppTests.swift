import Foundation
import Hummingbird
import HummingbirdAuthTesting
import HummingbirdTesting
import Testing

@testable import App

struct TestArguments: AppArguments {
    var migrate: Bool = true
    var inMemoryDatabase: Bool = true
}

struct AppTests {
    func createUser<Return>(
        name: String,
        password: String,
        client: some TestClientProtocol,
        _ callback: @escaping (TestResponse) throws -> Return
    ) async throws -> Return {
        let request = CreateUserRequest(name: name, password: password)
        return try await client.execute(
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
        client: some TestClientProtocol,
        _ callback: @escaping (TestResponse) throws -> Return
    ) async throws -> Return {
        try await client.execute(
            uri: "/user/login",
            method: .post,
            auth: .basic(username: name, password: password)
        ) {
            try callback($0)
        }
    }

    func getCurrent<Return>(
        cookie: String?,
        client: some TestClientProtocol,
        _ callback: @escaping (TestResponse) throws -> Return
    ) async throws -> Return {
        try await client.execute(
            uri: "/user",
            method: .get,
            headers: cookie.map { [.cookie: $0] } ?? [:]
        ) {
            try callback($0)
        }
    }

    @Test func testCreateUser() async throws {
        let app = try await buildApplication(TestArguments(), configuration: .init())
        try await app.test(.live) { client in
            try await self.createUser(name: "adam", password: "test", client: client) { response in
                #expect(response.status == .ok)
            }
            try await self.createUser(name: "adam", password: "test", client: client) { response in
                #expect(response.status == .conflict)
            }
        }
    }

    @Test func testLogin() async throws {
        let app = try await buildApplication(TestArguments(), configuration: .init())
        try await app.test(.live) { client in
            try await self.createUser(name: "adam", password: "testLogin", client: client) { response in
                #expect(response.status == .ok)
            }
            try await self.login(name: "adam", password: "testLogin", client: client) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test func testSession() async throws {
        let app = try await buildApplication(TestArguments(), configuration: .init())
        try await app.test(.live) { client in
            try await self.createUser(name: "john", password: "testSession", client: client) { response in
                #expect(response.status == .ok)
            }
            let cookie = try await self.login(name: "john", password: "testSession", client: client) { response in
                #expect(response.status == .ok)
                return try #require(response.headers[.setCookie])
            }
            try await self.getCurrent(cookie: cookie, client: client) { response in
                #expect(response.status == .ok)
                let user = try JSONDecoder().decode(UserResponse.self, from: response.body)
                #expect(user.name == "john")
            }
            try await self.getCurrent(cookie: nil, client: client) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
}
