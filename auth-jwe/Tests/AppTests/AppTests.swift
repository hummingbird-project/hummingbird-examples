//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2026 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import App
import Configuration
import Foundation
import Hummingbird
import HummingbirdAuthTesting
import HummingbirdTesting
import JWSETKit
import Testing

private let testReader = ConfigReader(providers: [
    InMemoryProvider(values: [
        "log.level": "trace",
    ]),
])

struct AppTests {
    @Test
    func appStarts() async throws {
        let app = try await buildApplication(reader: testReader)
        try await app.test(.router) { client in
            try await client.execute(uri: "/does-not-exist", method: .get) { response in
                #expect(response.status == .notFound)
            }
        }
    }

    @Test
    func nestedTokenRoundTrip() throws {
        let keys = try TokenKeys()
        let user = User(username: "alice", passwordHash: nil, email: "alice@example.com", role: "admin")
        let token = try user.issueNestedToken(
            keys: keys,
            issuer: "auth-jwe-example",
            audience: "hummingbird-clients"
        )
        // The token is a 5-segment JWE, not a 3-segment JWS: claims are not
        // readable by the client.
        #expect(token.split(separator: ".").count == 5)
        #expect(!token.contains("alice"))

        let jwt = try JSONWebEncryption(from: token)
            .openNestedToken(keys: keys, audience: "hummingbird-clients")
        #expect(jwt.payload.subject == "alice")
        #expect(jwt.payload.email == "alice@example.com")
        #expect(jwt.payload.storage["role"] == "admin")
    }

    @Test
    func loginReturnsEncryptedToken() async throws {
        let keys = try TokenKeys()
        let app = try await buildApplication(reader: testReader, keys: keys)
        try await app.test(.router) { client in
            let token = try await client.execute(
                uri: "/user/login",
                method: .post,
                auth: .basic(username: "alice", password: "alice-password")
            ) { response in
                #expect(response.status == .ok)
                let body = try JSONDecoder().decode([String: String].self, from: response.body)
                return try #require(body["token"])
            }
            // Opaque to the client...
            #expect(token.split(separator: ".").count == 5)
            #expect(!token.contains("alice"))
            // ...but the server can open it and sees the private claims.
            let jwt = try JSONWebEncryption(from: token)
                .openNestedToken(keys: keys, audience: "hummingbird-clients")
            #expect(jwt.payload.subject == "alice")
            #expect(jwt.payload.email == "alice@example.com")
            #expect(jwt.payload.storage["role"] == "admin")
        }
    }

    @Test
    func loginWithWrongPasswordFails() async throws {
        let app = try await buildApplication(reader: testReader)
        try await app.test(.router) { client in
            try await client.execute(
                uri: "/user/login",
                method: .post,
                auth: .basic(username: "alice", password: "wrong")
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    @Test
    func protectedRouteReturnsPrivateClaims() async throws {
        let app = try await buildApplication(reader: testReader)
        try await app.test(.router) { client in
            let token = try await client.execute(
                uri: "/user/login",
                method: .post,
                auth: .basic(username: "alice", password: "alice-password")
            ) { response in
                let body = try JSONDecoder().decode([String: String].self, from: response.body)
                return try #require(body["token"])
            }
            try await client.execute(uri: "/auth", method: .get, auth: .bearer(token)) { response in
                #expect(response.status == .ok)
                let body = try JSONDecoder().decode([String: String].self, from: response.body)
                #expect(body["username"] == "alice")
                #expect(body["email"] == "alice@example.com")
                #expect(body["role"] == "admin")
            }
        }
    }

    @Test
    func protectedRouteRejectsTokenEncryptedToWrongKey() async throws {
        let keys = try TokenKeys()
        let strangerKeys = try TokenKeys()
        let app = try await buildApplication(reader: testReader, keys: keys)
        try await app.test(.router) { client in
            let foreign = try User(username: "alice", passwordHash: nil, email: nil, role: nil)
                .issueNestedToken(
                    keys: strangerKeys,
                    issuer: "auth-jwe-example",
                    audience: "hummingbird-clients"
                )
            try await client.execute(uri: "/auth", method: .get, auth: .bearer(foreign)) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    @Test
    func protectedRouteRejectsInnerJWTSignedByWrongKey() async throws {
        let keys = try TokenKeys()
        let strangerKeys = try TokenKeys()
        // Encrypted to the right key but signed by the wrong one.
        let mixed = TokenKeys(signing: strangerKeys.signing, encryption: keys.encryption)
        let app = try await buildApplication(reader: testReader, keys: keys)
        try await app.test(.router) { client in
            let forged = try User(username: "alice", passwordHash: nil, email: nil, role: nil)
                .issueNestedToken(
                    keys: mixed,
                    issuer: "auth-jwe-example",
                    audience: "hummingbird-clients"
                )
            try await client.execute(uri: "/auth", method: .get, auth: .bearer(forged)) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    @Test
    func protectedRouteRejectsExpiredInnerToken() async throws {
        let keys = try TokenKeys()
        let app = try await buildApplication(reader: testReader, keys: keys)
        try await app.test(.router) { client in
            let expired = try User(username: "alice", passwordHash: nil, email: nil, role: nil)
                .issueNestedToken(
                    keys: keys,
                    issuer: "auth-jwe-example",
                    audience: "hummingbird-clients",
                    expiresIn: -3600
                )
            try await client.execute(uri: "/auth", method: .get, auth: .bearer(expired)) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    @Test
    func protectedRouteRejectsPlainJWSToken() async throws {
        // A signed-but-not-encrypted token must be rejected: this server only
        // accepts JWE bearer tokens.
        let keys = try TokenKeys()
        let app = try await buildApplication(reader: testReader, keys: keys)
        try await app.test(.router) { client in
            let plainJWS = try String(JSONWebToken(
                payload: .init {
                    $0 = $0.addBase(issuer: "auth-jwe-example", audience: ["hummingbird-clients"], subject: "alice", expiresIn: 3600)
                },
                using: keys.signing
            ))
            try await client.execute(uri: "/auth", method: .get, auth: .bearer(plainJWS)) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    @Test
    func protectedRouteRejectsMissingToken() async throws {
        let app = try await buildApplication(reader: testReader)
        try await app.test(.router) { client in
            try await client.execute(uri: "/auth", method: .get) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
}
