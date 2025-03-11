import Foundation
import Hummingbird
import HummingbirdAuthTesting
import HummingbirdTesting
import JWTKit
import XCTest

@testable import App

final class AppTests: XCTestCase {
    struct TestAppArguments: AppArguments {
        let inMemoryDatabase: Bool = true
        let migrate: Bool = true
        let hostname: String = "127.0.0.1"
        let port = 8080
    }

    func testCreateUser() async throws {
        let app = try await buildApplication(TestAppArguments())

        try await app.test(.router) { client in
            let requestBody = TestCreateUserRequest(name: "adam", password: "testpassword")
            try await client.execute(
                uri: "/user",
                method: .put,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                XCTAssertEqual(response.status, .created)
                let userResponse = try JSONDecoder().decode(TestCreateUserResponse.self, from: response.body)
                XCTAssertEqual(userResponse.name, "adam")
            }
        }
    }

    func testAuthenticateWithJWT() async throws {
        let app = try await buildApplication(TestAppArguments())

        try await app.test(.router) { client in
            // create user
            let requestBody = TestCreateUserRequest(name: "adam", password: "testpassword")
            try await client.execute(
                uri: "/user",
                method: .put,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                XCTAssertEqual(response.status, .created)
                let userResponse = try JSONDecoder().decode(TestCreateUserResponse.self, from: response.body)
                XCTAssertEqual(userResponse.name, "adam")
            }
            // login
            let token = try await client.execute(
                uri: "/user/login",
                method: .post,
                auth: .basic(username: "adam", password: "testpassword")
            ) { response in
                XCTAssertEqual(response.status, .ok)
                let responseBody = try JSONDecoder().decode([String: String].self, from: response.body)
                return try XCTUnwrap(responseBody["token"])
            }
            // authenticate with JWT
            try await client.execute(uri: "/auth", method: .get, auth: .bearer(token)) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }
}

struct TestCreateUserRequest: Encodable {
    let name: String
    let password: String?

    init(name: String, password: String?) {
        self.name = name
        self.password = password
    }
}

struct TestCreateUserResponse: Decodable {
    let name: String
    let id: String
}
