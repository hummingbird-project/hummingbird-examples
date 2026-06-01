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

// MARK: - Encodable helpers

private struct TestCreateUserRequest: Encodable {
    let name: String
    let password: String
    let department: String
    let clearanceLevel: Int
    let roles: [String]
    let permissions: [String]

    enum CodingKeys: String, CodingKey {
        case name, password, department
        case clearanceLevel = "clearanceLevel"
        case roles, permissions
    }
}

private struct TestCreateDocumentRequest: Encodable {
    let title: String
    let content: String
    let department: String
    let classification: Int
}

private struct TestUpdateDocumentRequest: Encodable {
    let title: String?
    let content: String?
}

private struct TestDocumentResponse: Decodable {
    let id: UUID
    let title: String
    let content: String
    let department: String
    let classification: Int
    let ownerID: UUID
}

// MARK: - Shared helpers

private func createUser(
    name: String,
    password: String,
    department: String,
    clearanceLevel: Int,
    roles: [String] = [],
    permissions: [String] = [],
    client: some TestClientProtocol
) async throws {
    let body = TestCreateUserRequest(
        name: name,
        password: password,
        department: department,
        clearanceLevel: clearanceLevel,
        roles: roles,
        permissions: permissions
    )
    try await client.execute(
        uri: "/user",
        method: .put,
        body: JSONEncoder().encodeAsByteBuffer(body, allocator: ByteBufferAllocator())
    ) { response in
        #expect(response.status == .created, "Failed to create user '\(name)'")
    }
}

private func createDocument(
    title: String,
    content: String = "Some content",
    department: String,
    classification: Int = 0,
    auth username: String,
    password: String,
    client: some TestClientProtocol
) async throws -> TestDocumentResponse {
    let body = TestCreateDocumentRequest(
        title: title,
        content: content,
        department: department,
        classification: classification
    )
    return try await client.execute(
        uri: "/documents",
        method: .post,
        auth: .basic(username: username, password: password),
        body: JSONEncoder().encodeAsByteBuffer(body, allocator: ByteBufferAllocator())
    ) { response -> TestDocumentResponse in
        #expect(response.status == .created, "Failed to create document '\(title)'")
        return try JSONDecoder().decode(TestDocumentResponse.self, from: response.body)
    }
}

// MARK: - Tests

struct AppTests {
    /// Always passes the business-hours gate so time of day doesn't affect tests.
    struct TestAppArguments: AppArguments {
        let inMemoryDatabase = true
        let migrate = true
        let hostname = "127.0.0.1"
        let port = 8080
        let allowedDeletionHours: Range<Int> = 0..<24  // always allowed in tests
    }

    // MARK: Public access

    @Test func testListDocumentsIsPublic() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            try await client.execute(uri: "/documents", method: .get) { response in
                #expect(response.status == .ok)
            }
        }
    }

    // MARK: Department scoping (subject vs. resource attribute)

    @Test func testUserCanReadDocumentInSameDepartment() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            try await createUser(
                name: "eng",
                password: "pass",
                department: "engineering",
                clearanceLevel: 1,
                permissions: ["documents:create"],
                client: client
            )
            let doc = try await createDocument(
                title: "Eng Doc",
                department: "engineering",
                classification: 1,
                auth: "eng",
                password: "pass",
                client: client
            )
            try await client.execute(
                uri: "/documents/\(doc.id)",
                method: .get,
                auth: .basic(username: "eng", password: "pass")
            ) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test func testUserCannotReadDocumentInDifferentDepartment() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            // Engineering user creates a document
            try await createUser(
                name: "eng",
                password: "pass",
                department: "engineering",
                clearanceLevel: 0,
                permissions: ["documents:create"],
                client: client
            )
            // Finance user tries to read it
            try await createUser(
                name: "fin",
                password: "pass",
                department: "finance",
                clearanceLevel: 0,
                client: client
            )
            let doc = try await createDocument(
                title: "Eng Doc",
                department: "engineering",
                auth: "eng",
                password: "pass",
                client: client
            )
            try await client.execute(
                uri: "/documents/\(doc.id)",
                method: .get,
                auth: .basic(username: "fin", password: "pass")
            ) { response in
                #expect(response.status == .forbidden)
            }
        }
    }

    @Test func testAdminCanReadDocumentInAnyDepartment() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            try await createUser(
                name: "eng",
                password: "pass",
                department: "engineering",
                clearanceLevel: 0,
                permissions: ["documents:create"],
                client: client
            )
            try await createUser(
                name: "admin",
                password: "pass",
                department: "finance",
                clearanceLevel: 3,
                roles: ["admin"],
                client: client
            )
            let doc = try await createDocument(
                title: "Eng Doc",
                department: "engineering",
                auth: "eng",
                password: "pass",
                client: client
            )
            // Admin is in "finance" but the admin role bypasses the department check
            try await client.execute(
                uri: "/documents/\(doc.id)",
                method: .get,
                auth: .basic(username: "admin", password: "pass")
            ) { response in
                #expect(response.status == .ok)
            }
        }
    }

    // MARK: Clearance level (numeric attribute comparison)

    @Test func testSufficientClearanceGrantsAccess() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            try await createUser(
                name: "analyst",
                password: "pass",
                department: "engineering",
                clearanceLevel: 2,
                permissions: ["documents:create"],
                client: client
            )
            // classification=2 (confidential) — analyst has clearanceLevel=2
            let doc = try await createDocument(
                title: "Confidential",
                department: "engineering",
                classification: 2,
                auth: "analyst",
                password: "pass",
                client: client
            )
            try await client.execute(
                uri: "/documents/\(doc.id)",
                method: .get,
                auth: .basic(username: "analyst", password: "pass")
            ) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test func testInsufficientClearanceDeniesAccess() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            try await createUser(
                name: "creator",
                password: "pass",
                department: "engineering",
                clearanceLevel: 3,
                permissions: ["documents:create"],
                client: client
            )
            // Low-clearance reader in the same department
            try await createUser(
                name: "reader",
                password: "pass",
                department: "engineering",
                clearanceLevel: 0,
                client: client
            )
            // classification=2 (confidential)
            let doc = try await createDocument(
                title: "Confidential",
                department: "engineering",
                classification: 2,
                auth: "creator",
                password: "pass",
                client: client
            )
            try await client.execute(
                uri: "/documents/\(doc.id)",
                method: .get,
                auth: .basic(username: "reader", password: "pass")
            ) { response in
                #expect(response.status == .forbidden)
            }
        }
    }

    // MARK: Document ownership (async resource attribute)

    @Test func testOwnerCanUpdateDocument() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            try await createUser(
                name: "author",
                password: "pass",
                department: "engineering",
                clearanceLevel: 0,
                permissions: ["documents:create"],
                client: client
            )
            let doc = try await createDocument(
                title: "Original",
                department: "engineering",
                auth: "author",
                password: "pass",
                client: client
            )
            let updateBody = TestUpdateDocumentRequest(title: "Updated", content: nil)
            try await client.execute(
                uri: "/documents/\(doc.id)",
                method: .put,
                auth: .basic(username: "author", password: "pass"),
                body: JSONEncoder().encodeAsByteBuffer(updateBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test func testNonOwnerCannotUpdateDocument() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            try await createUser(
                name: "author",
                password: "pass",
                department: "engineering",
                clearanceLevel: 0,
                permissions: ["documents:create"],
                client: client
            )
            try await createUser(
                name: "other",
                password: "pass",
                department: "engineering",
                clearanceLevel: 0,
                client: client
            )
            let doc = try await createDocument(
                title: "Author's Doc",
                department: "engineering",
                auth: "author",
                password: "pass",
                client: client
            )
            let updateBody = TestUpdateDocumentRequest(title: "Hijacked", content: nil)
            try await client.execute(
                uri: "/documents/\(doc.id)",
                method: .put,
                auth: .basic(username: "other", password: "pass"),
                body: JSONEncoder().encodeAsByteBuffer(updateBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .forbidden)
            }
        }
    }

    @Test func testAdminCanUpdateAnyDocument() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            try await createUser(
                name: "author",
                password: "pass",
                department: "engineering",
                clearanceLevel: 0,
                permissions: ["documents:create"],
                client: client
            )
            try await createUser(
                name: "admin",
                password: "pass",
                department: "finance",
                clearanceLevel: 3,
                roles: ["admin"],
                client: client
            )
            let doc = try await createDocument(
                title: "Any Doc",
                department: "engineering",
                auth: "author",
                password: "pass",
                client: client
            )
            let updateBody = TestUpdateDocumentRequest(title: "Admin Edit", content: nil)
            try await client.execute(
                uri: "/documents/\(doc.id)",
                method: .put,
                auth: .basic(username: "admin", password: "pass"),
                body: JSONEncoder().encodeAsByteBuffer(updateBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }
        }
    }

    // MARK: Business hours (environment attribute)

    @Test func testAdminCanDeleteDuringAllowedHours() async throws {
        // TestAppArguments sets allowedDeletionHours = 0..<24 (always passes)
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            try await createUser(
                name: "author",
                password: "pass",
                department: "engineering",
                clearanceLevel: 0,
                permissions: ["documents:create"],
                client: client
            )
            try await createUser(
                name: "admin",
                password: "pass",
                department: "engineering",
                clearanceLevel: 3,
                roles: ["admin"],
                client: client
            )
            let doc = try await createDocument(
                title: "To Delete",
                department: "engineering",
                auth: "author",
                password: "pass",
                client: client
            )
            try await client.execute(
                uri: "/documents/\(doc.id)",
                method: .delete,
                auth: .basic(username: "admin", password: "pass")
            ) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test func testAdminCannotDeleteOutsideAllowedHours() async throws {
        // Override allowedDeletionHours to an empty range — always denied
        struct LockedArgs: AppArguments {
            let inMemoryDatabase = true
            let migrate = true
            let hostname = "127.0.0.1"
            let port = 8080
            let allowedDeletionHours: Range<Int> = 0..<0  // never passes
        }
        let app = try await buildApplication(LockedArgs())
        try await app.test(.router) { client in
            try await createUser(
                name: "author",
                password: "pass",
                department: "engineering",
                clearanceLevel: 0,
                permissions: ["documents:create"],
                client: client
            )
            try await createUser(
                name: "admin",
                password: "pass",
                department: "engineering",
                clearanceLevel: 3,
                roles: ["admin"],
                client: client
            )
            let doc = try await createDocument(
                title: "Protected",
                department: "engineering",
                auth: "author",
                password: "pass",
                client: client
            )
            try await client.execute(
                uri: "/documents/\(doc.id)",
                method: .delete,
                auth: .basic(username: "admin", password: "pass")
            ) { response in
                #expect(response.status == .forbidden)
            }
        }
    }

    @Test func testNonAdminCannotDeleteDocument() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            try await createUser(
                name: "author",
                password: "pass",
                department: "engineering",
                clearanceLevel: 0,
                permissions: ["documents:create"],
                client: client
            )
            let doc = try await createDocument(
                title: "My Doc",
                department: "engineering",
                auth: "author",
                password: "pass",
                client: client
            )
            // author has no admin role — 403 even during allowed hours
            try await client.execute(
                uri: "/documents/\(doc.id)",
                method: .delete,
                auth: .basic(username: "author", password: "pass")
            ) { response in
                #expect(response.status == .forbidden)
            }
        }
    }
}
