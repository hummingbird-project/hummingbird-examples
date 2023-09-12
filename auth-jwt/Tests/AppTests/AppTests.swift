@testable import App
import Foundation
import Hummingbird
import HummingbirdAuthXCT
import HummingbirdXCT
import JWTKit
import XCTest

final class AppTests: XCTestCase {
    struct TestAppArguments: AppArguments {
        let inMemoryDatabase: Bool = true
        let migrate: Bool = true
    }

    func testApp() async throws {
        let app = HBApplication(testing: .live)
        try await app.configure(arguments: TestAppArguments())

        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.body.map { String(buffer: $0) }, "Hello")
        }
    }

    func testCreateUser() async throws {
        let app = HBApplication(testing: .live)
        try await app.configure(arguments: TestAppArguments())

        try app.XCTStart()
        defer { app.XCTStop() }

        let requestBody = TestCreateUserRequest(name: "adam", password: "testpassword")
        try app.XCTExecute(uri: "/user", method: .PUT, body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())) { response in
            XCTAssertEqual(response.status, .ok)
            let body = try XCTUnwrap(response.body)
            let userResponse = try JSONDecoder().decode(TestCreateUserResponse.self, from: body)
            XCTAssertEqual(userResponse.name, "adam")
        }
    }

    func testAuthenticateWithLocallyCreatedJWT() async throws {
        let app = HBApplication(testing: .live)
        try await app.configure(arguments: TestAppArguments())

        try app.XCTStart()
        defer { app.XCTStop() }

        let requestBody = TestCreateUserRequest(name: "adam", password: "testpassword")
        try app.XCTExecute(uri: "/user", method: .PUT, body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())) { response in
            XCTAssertEqual(response.status, .ok)
            let body = try XCTUnwrap(response.body)
            let userResponse = try JSONDecoder().decode(TestCreateUserResponse.self, from: body)
            XCTAssertEqual(userResponse.name, "adam")
        }
        let token = try app.XCTExecute(
            uri: "/user/login",
            method: .POST,
            auth: .basic(username: "adam", password: "testpassword")
        ) { response in
            XCTAssertEqual(response.status, .ok)
            let body = try XCTUnwrap(response.body)
            let responseBody = try JSONDecoder().decode([String: String].self, from: body)
            return try XCTUnwrap(responseBody["token"])
        }
        try app.XCTExecute(uri: "/auth", method: .GET, auth: .bearer(token)) { response in
            XCTAssertEqual(response.status, .ok)
        }
    }

    func testAuthenticateWithServiceCreatedJWT() async throws {
        let app = HBApplication(testing: .live)
        try await app.configure(arguments: TestAppArguments())

        try app.XCTStart()
        defer { app.XCTStop() }

        // create JWT
        let payload = JWTPayloadData(
            subject: .init(value: "John Smith"),
            expiration: .init(value: Date(timeIntervalSinceNow: 12 * 60 * 60))
        )
        let signers = JWTSigners()
        signers.use(.hs256(key: "my-secret-key"), kid: "_hb_local_")
        let token = try signers.sign(payload, kid: "_hb_local_")

        try app.XCTExecute(uri: "/auth", method: .GET, auth: .bearer(token)) { response in
            XCTAssertEqual(response.status, .ok)
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "Authenticated (Subject: John Smith)")
        }
    }
}

struct TestCreateUserRequest: Encodable {
    let name: String
    let password: String?

    internal init(name: String, password: String?) {
        self.name = name
        self.password = password
    }
}

struct TestCreateUserResponse: Decodable {
    let name: String
    let id: String
}
