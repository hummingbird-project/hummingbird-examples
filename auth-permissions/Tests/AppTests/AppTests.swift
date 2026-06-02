//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import Hummingbird
import HummingbirdAuthTesting
import HummingbirdTesting
import Testing

@testable import App

// MARK: - Encodable test helpers

private struct TestCreateUserRequest: Encodable {
    let name: String
    let password: String
    let roles: Int32
    let permissions: Int32
}

private struct TestCreatePostRequest: Encodable {
    let title: String
    let body: String
}

private struct TestPostResponse: Decodable {
    let id: UUID
    let title: String
    let body: String
}

// MARK: - Shared setup helper

/// Creates a user via `PUT /user`.
/// Accepts ``Role`` and ``Permission`` OptionSets directly — no string arrays needed.
private func createUser(
    name: String,
    password: String,
    roles: Role,
    permissions: Permission = [],
    client: some TestClientProtocol
) async throws {
    let body = TestCreateUserRequest(
        name: name,
        password: password,
        roles: roles.rawValue,
        permissions: permissions.rawValue
    )
    try await client.execute(
        uri: "/user",
        method: .put,
        body: JSONEncoder().encodeAsByteBuffer(body, allocator: ByteBufferAllocator())
    ) { response in
        #expect(response.status == .created, "Failed to create user '\(name)'")
    }
}

// MARK: - Tests

struct AppTests {
    struct TestAppArguments: AppArguments {
        let inMemoryDatabase = true
        let migrate = true
        let hostname = "127.0.0.1"
        let port = 8080
    }

    // MARK: Basic sanity

    @Test func testCreateUser() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            try await createUser(
                name: "alice",
                password: "secret",
                roles: .admin,
                permissions: [.postsRead, .postsWrite, .postsDelete],
                client: client
            )
        }
    }

    @Test func testUnauthenticatedGetPostsReturns200() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            try await client.execute(uri: "/posts", method: .get) { response in
                #expect(response.status == .ok)
            }
        }
    }

    // MARK: Admin capabilities

    @Test func testAdminCanCreatePost() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            try await createUser(
                name: "admin",
                password: "pass",
                roles: .admin,
                permissions: [.postsRead, .postsWrite, .postsDelete],
                client: client
            )
            let postBody = TestCreatePostRequest(title: "Hello", body: "World")
            try await client.execute(
                uri: "/posts",
                method: .post,
                auth: .basic(username: "admin", password: "pass"),
                body: JSONEncoder().encodeAsByteBuffer(postBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
        }
    }

    @Test func testAdminCanDeletePost() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            try await createUser(
                name: "admin",
                password: "pass",
                roles: .admin,
                permissions: [.postsRead, .postsWrite, .postsDelete],
                client: client
            )
            let postBody = TestCreatePostRequest(title: "To Delete", body: "Delete me")
            let post = try await client.execute(
                uri: "/posts",
                method: .post,
                auth: .basic(username: "admin", password: "pass"),
                body: JSONEncoder().encodeAsByteBuffer(postBody, allocator: ByteBufferAllocator())
            ) { response -> TestPostResponse in
                #expect(response.status == .created)
                return try JSONDecoder().decode(TestPostResponse.self, from: response.body)
            }
            try await client.execute(
                uri: "/posts/\(post.id)",
                method: .delete,
                auth: .basic(username: "admin", password: "pass")
            ) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test func testAdminCanListUsers() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            try await createUser(
                name: "admin",
                password: "pass",
                roles: .admin,
                permissions: .postsRead,
                client: client
            )
            try await client.execute(
                uri: "/admin/users",
                method: .get,
                auth: .basic(username: "admin", password: "pass")
            ) { response in
                #expect(response.status == .ok)
            }
        }
    }

    // MARK: Editor capabilities

    @Test func testEditorCanCreatePost() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            try await createUser(
                name: "editor",
                password: "pass",
                roles: .editor,
                permissions: [.postsRead, .postsWrite],
                client: client
            )
            let postBody = TestCreatePostRequest(title: "Editor Post", body: "By editor")
            try await client.execute(
                uri: "/posts",
                method: .post,
                auth: .basic(username: "editor", password: "pass"),
                body: JSONEncoder().encodeAsByteBuffer(postBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
        }
    }

    @Test func testEditorCannotDeletePost() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            try await createUser(
                name: "admin",
                password: "adminpass",
                roles: .admin,
                permissions: [.postsRead, .postsWrite, .postsDelete],
                client: client
            )
            try await createUser(
                name: "editor",
                password: "editorpass",
                roles: .editor,
                permissions: [.postsRead, .postsWrite],
                client: client
            )
            let postBody = TestCreatePostRequest(title: "Admin Post", body: "By admin")
            let post = try await client.execute(
                uri: "/posts",
                method: .post,
                auth: .basic(username: "admin", password: "adminpass"),
                body: JSONEncoder().encodeAsByteBuffer(postBody, allocator: ByteBufferAllocator())
            ) { response -> TestPostResponse in
                #expect(response.status == .created)
                return try JSONDecoder().decode(TestPostResponse.self, from: response.body)
            }
            try await client.execute(
                uri: "/posts/\(post.id)",
                method: .delete,
                auth: .basic(username: "editor", password: "editorpass")
            ) { response in
                #expect(response.status == .forbidden)
            }
        }
    }

    @Test func testEditorCannotListUsers() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            try await createUser(
                name: "editor",
                password: "pass",
                roles: .editor,
                permissions: [.postsRead, .postsWrite],
                client: client
            )
            try await client.execute(
                uri: "/admin/users",
                method: .get,
                auth: .basic(username: "editor", password: "pass")
            ) { response in
                #expect(response.status == .forbidden)
            }
        }
    }

    // MARK: Reader capabilities

    @Test func testReaderCannotCreatePost() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            try await createUser(
                name: "reader",
                password: "pass",
                roles: .reader,
                permissions: .postsRead,
                client: client
            )
            let postBody = TestCreatePostRequest(title: "Reader Post", body: "Unauthorized")
            try await client.execute(
                uri: "/posts",
                method: .post,
                auth: .basic(username: "reader", password: "pass"),
                body: JSONEncoder().encodeAsByteBuffer(postBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .forbidden)
            }
        }
    }

    @Test func testReaderCannotDeletePost() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            try await createUser(
                name: "admin",
                password: "adminpass",
                roles: .admin,
                permissions: [.postsRead, .postsWrite, .postsDelete],
                client: client
            )
            try await createUser(
                name: "reader",
                password: "readerpass",
                roles: .reader,
                permissions: .postsRead,
                client: client
            )
            let postBody = TestCreatePostRequest(title: "Post", body: "Content")
            let post = try await client.execute(
                uri: "/posts",
                method: .post,
                auth: .basic(username: "admin", password: "adminpass"),
                body: JSONEncoder().encodeAsByteBuffer(postBody, allocator: ByteBufferAllocator())
            ) { response -> TestPostResponse in
                #expect(response.status == .created)
                return try JSONDecoder().decode(TestPostResponse.self, from: response.body)
            }
            try await client.execute(
                uri: "/posts/\(post.id)",
                method: .delete,
                auth: .basic(username: "reader", password: "readerpass")
            ) { response in
                #expect(response.status == .forbidden)
            }
        }
    }

    // MARK: AnyOf — permission without role

    @Test func testUserWithDeletePermissionCanDeleteWithoutAdminRole() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            // moderator: no admin role, but holds postsDelete permission
            try await createUser(
                name: "moderator",
                password: "pass",
                roles: .moderator,
                permissions: [.postsRead, .postsWrite, .postsDelete],
                client: client
            )
            let postBody = TestCreatePostRequest(title: "Some Post", body: "Content")
            let post = try await client.execute(
                uri: "/posts",
                method: .post,
                auth: .basic(username: "moderator", password: "pass"),
                body: JSONEncoder().encodeAsByteBuffer(postBody, allocator: ByteBufferAllocator())
            ) { response -> TestPostResponse in
                #expect(response.status == .created)
                return try JSONDecoder().decode(TestPostResponse.self, from: response.body)
            }
            // postsDelete permission satisfies anyOf(admin role, postsDelete permission)
            try await client.execute(
                uri: "/posts/\(post.id)",
                method: .delete,
                auth: .basic(username: "moderator", password: "pass")
            ) { response in
                #expect(response.status == .ok)
            }
        }
    }
}
