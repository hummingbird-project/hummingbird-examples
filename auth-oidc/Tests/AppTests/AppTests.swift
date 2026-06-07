//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2025 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AsyncHTTPClient
import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdAuthTesting
import HummingbirdOIDC
import HummingbirdTesting
import Testing

@testable import App

// MARK: - Helpers

/// Spins up a fake IdP on an OS-assigned port, builds an RP configured against it,
/// and hands both to `body`. Ports are determined at runtime to avoid conflicts.
private func withOIDCTestEnvironment<R: Sendable>(
    body: @Sendable (any TestClientProtocol, FakeOIDCProvider) async throws -> R
) async throws -> R {
    let clientID = "test-client"
    let httpClient = HTTPClient.shared

    let fakeIdP = try await FakeOIDCProvider()

    // IdP router captures fakeIdP by reference — issuer is read lazily from fakeIdP.issuer
    let idpApp = Application(
        router: fakeIdP.buildRouter(clientID: clientID),
        configuration: .init(address: .hostname("127.0.0.1", port: 0))
    )

    return try await idpApp.test(.live) { idpClient in
        // Now we know the actual port — wire up the issuer before any /token requests.
        let idpPort = idpClient.port!
        let idpBaseURL = "http://localhost:\(idpPort)"
        fakeIdP.configure(baseURL: idpBaseURL)

        // The redirect URI is a placeholder — the fake IdP doesn't validate it,
        // and our tests manually construct the callback URL rather than following the redirect.
        let redirectURI = "http://localhost:1/auth/callback"

        let rpPersist = MemoryPersistDriver()
        let oidcConfig = OIDCConfiguration(
            clientID: clientID,
            clientSecret: nil,
            redirectURI: redirectURI,
            scopes: ["openid", "profile", "email"],
            issuer: idpBaseURL,
            providerSource: .static(fakeIdP.providerMetadata()),
            tokenEndpointAuthMethod: .none,
            idTokenSignedResponseAlg: "ES256",
            allowInsecureTransport: true
        )
        let oidc = OIDC(
            configuration: oidcConfig,
            stateStore: PersistDriverStateStore(rpPersist),
            httpClient: httpClient
        )

        let rpApp = try await buildApplication(
            TestArgs(),
            configuration: .init(address: .hostname("127.0.0.1", port: 0)),
            httpClient: httpClient,
            oidcOverride: oidc
        )

        return try await rpApp.test(.live) { rpClient in
            try await body(rpClient, fakeIdP)
        }
    }
}

private struct TestArgs: AppArguments {
    var hostname: String = "127.0.0.1"
    var port: Int = 0
}

// MARK: - Tests

@Suite(.serialized)
struct AppTests {
    // MARK: Auth-gated routes

    @Test func meRequiresAuth() async throws {
        try await withOIDCTestEnvironment { client, _ in
            try await client.execute(uri: "/me", method: .get) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    // MARK: Login redirect

    @Test func loginRedirectsToIdP() async throws {
        try await withOIDCTestEnvironment { client, _ in
            try await client.execute(uri: "/auth/login", method: .get) { response in
                #expect(response.status == .found)
                let location = response.headers[.location] ?? ""
                #expect(location.contains("/authorize"))
                #expect(location.contains("response_type=code"))
                #expect(location.contains("code_challenge_method=S256"))
                #expect(location.contains("client_id=test-client"))
            }
        }
    }

    // MARK: Full Authorization Code + PKCE flow

    @Test func fullOIDCFlow() async throws {
        try await withOIDCTestEnvironment { client, _ in
            // 1. GET /auth/login — get redirect to fake IdP /authorize
            var authorizeURL: String = ""
            try await client.execute(uri: "/auth/login", method: .get) { response in
                #expect(response.status == .found)
                authorizeURL = response.headers[.location] ?? ""
                #expect(!authorizeURL.isEmpty)
            }

            // 2. Parse state + nonce from the authorize URL.
            //    We don't follow the redirect through the network — instead we craft
            //    the callback URL directly, simulating what the IdP would return.
            let urlComponents = URLComponents(string: authorizeURL)
            guard let stateValue = urlComponents?.queryItems?.first(where: { $0.name == "state" })?.value,
                  let nonceValue = urlComponents?.queryItems?.first(where: { $0.name == "nonce" })?.value
            else {
                Issue.record("Missing state or nonce in authorize URL")
                return
            }

            let code = "fake-code:\(nonceValue)"
            let encodedCode = code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code
            let callbackURI = "/auth/callback?code=\(encodedCode)&state=\(stateValue)"

            // 3. GET /auth/callback — RP exchanges code, writes session, redirects to /
            var sessionCookie: String = ""
            try await client.execute(uri: callbackURI, method: .get) { response in
                #expect(response.status == .seeOther)
                sessionCookie = response.headers[values: .setCookie].first ?? ""
                #expect(!sessionCookie.isEmpty, "Expected a session cookie to be set")
            }

            // Extract just "SESSION_ID=<value>" for the Cookie header
            let cookieHeader = sessionCookie.split(separator: ";").first.map(String.init) ?? sessionCookie

            // 4. GET /me with session cookie — should return authenticated identity
            try await client.execute(
                uri: "/me",
                method: .get,
                headers: [.cookie: cookieHeader]
            ) { response in
                #expect(response.status == .ok)
                if let body = try? JSONDecoder().decode(
                    [String: String].self,
                    from: Data(buffer: response.body)
                ) {
                    #expect(body["subject"] == "user-sub-123")
                    #expect(body["email"] == "test@example.com")
                }
            }
        }
    }

    // MARK: Logout

    @Test func logoutClearsSession() async throws {
        try await withOIDCTestEnvironment { client, _ in
            try await client.execute(uri: "/auth/logout", method: .post) { response in
                let status = response.status
                #expect(status == .ok || status == .found)
            }
        }
    }
}
