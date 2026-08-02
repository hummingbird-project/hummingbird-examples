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

import Foundation
import Hummingbird
import HummingbirdOIDC
import JWTKit

/// An in-process fake OIDC provider for integration tests.
///
/// Keys are generated at init. Call `configure(baseURL:)` once the server
/// has bound to its actual port so that token issuance uses the real issuer URL.
final class FakeOIDCProvider: @unchecked Sendable {
    private(set) var baseURL: String = ""
    private(set) var issuer: String = ""

    let privateKey: ES256PrivateKey
    let keyCollection: JWTKeyCollection
    let kid: JWKIdentifier
    /// Pre-computed JWK JSON served at /jwks
    let jwksJSON: String

    init() async throws {
        let key = ES256PrivateKey()
        self.privateKey = key
        self.kid = JWKIdentifier(string: "fake-key-1")

        let collection = JWTKeyCollection()
        await collection.add(ecdsa: key, kid: kid)
        self.keyCollection = collection

        guard let params = key.parameters else {
            throw FakeOIDCProviderError.keyExportFailed
        }
        let xURL = Self.base64ToBase64URL(params.x)
        let yURL = Self.base64ToBase64URL(params.y)
        self.jwksJSON = """
        {"keys":[{"kty":"EC","kid":"fake-key-1","alg":"ES256","use":"sig","crv":"P-256","x":"\(xURL)","y":"\(yURL)"}]}
        """
    }

    /// Call after the server has bound to set the real issuer URL.
    func configure(baseURL: String) {
        self.baseURL = baseURL
        self.issuer = baseURL
    }

    enum FakeOIDCProviderError: Error {
        case keyExportFailed
    }

    // MARK: - OIDCProviderMetadata

    func providerMetadata() -> OIDCProviderMetadata {
        OIDCProviderMetadata(
            issuer: issuer,
            authorizationEndpoint: "\(baseURL)/authorize",
            tokenEndpoint: "\(baseURL)/token",
            jwksURI: "\(baseURL)/jwks",
            userInfoEndpoint: "\(baseURL)/userinfo",
            endSessionEndpoint: "\(baseURL)/logout"
        )
    }

    // MARK: - Router

    func buildRouter(clientID: String) -> Router<BasicRequestContext> {
        let router = Router(context: BasicRequestContext.self)

        // Discovery document
        router.get(".well-known/openid-configuration") { [self] _, _ -> Response in
            let body = try JSONEncoder().encodeAsByteBuffer(self.providerMetadata(), allocator: .init())
            return Response(status: .ok, headers: [.contentType: "application/json"], body: .init(byteBuffer: body))
        }

        // JWKS
        router.get("jwks") { [self] _, _ -> Response in
            var headers = HTTPFields()
            headers[.contentType] = "application/json"
            return Response(
                status: .ok,
                headers: headers,
                body: .init(byteBuffer: ByteBuffer(string: self.jwksJSON))
            )
        }

        // /authorize — immediately redirect to redirect_uri with code and state.
        // Encodes the nonce into the code (fake-code:<nonce>) so /token can echo it back.
        router.get("authorize") { request, _ -> Response in
            let params = request.uri.queryParameters
            let state = params.get("state").map { String($0) } ?? ""
            let nonce = params.get("nonce").map { String($0) } ?? ""
            let redirectURI = params.get("redirect_uri").map { String($0) } ?? ""
            let code = "fake-code:\(nonce)"
            let encodedCode = code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code
            return Response(
                status: .found,
                headers: [.location: "\(redirectURI)?code=\(encodedCode)&state=\(state)"]
            )
        }

        // /token — issue a signed ID token, echoing the nonce from the code
        router.post("token") { [self] request, _ -> Response in
            let body = try await request.body.collect(upTo: 64 * 1024)
            let bodyStr = String(buffer: body)
            let code = Self.formValue("code", from: bodyStr)
            let nonce: String? = code.flatMap { c in
                guard c.hasPrefix("fake-code:") else { return nil }
                return String(c.dropFirst("fake-code:".count))
            }

            let idToken = try await self.issueIDToken(
                subject: "user-sub-123",
                clientID: clientID,
                nonce: nonce
            )
            struct TokenResponseBody: Encodable {
                let id_token: String
                let access_token: String
                let token_type: String
                let expires_in: Int
            }
            let tokenResponse = TokenResponseBody(
                id_token: idToken,
                access_token: "fake-access-token",
                token_type: "Bearer",
                expires_in: 3600
            )
            let responseBody = try JSONEncoder().encodeAsByteBuffer(tokenResponse, allocator: .init())
            return Response(
                status: .ok,
                headers: [.contentType: "application/json"],
                body: .init(byteBuffer: responseBody)
            )
        }

        // /userinfo
        router.get("userinfo") { _, _ -> Response in
            let body = ByteBuffer(string: #"{"sub":"user-sub-123","name":"Test User","email":"test@example.com"}"#)
            return Response(status: .ok, headers: [.contentType: "application/json"], body: .init(byteBuffer: body))
        }

        return router
    }

    // MARK: - Token signing

    func issueIDToken(subject: String, clientID: String, nonce: String?) async throws -> String {
        struct IDTokenPayload: JWTPayload {
            var iss: IssuerClaim
            var sub: SubjectClaim
            var aud: AudienceClaim
            var exp: ExpirationClaim
            var iat: IssuedAtClaim
            var nonce: String?
            var name: String? = "Test User"
            var email: String? = "test@example.com"
            func verify(using algorithm: some JWTAlgorithm) async throws {
                try exp.verifyNotExpired()
            }
        }
        let payload = IDTokenPayload(
            iss: IssuerClaim(value: issuer),
            sub: SubjectClaim(value: subject),
            aud: AudienceClaim(value: [clientID]),
            exp: ExpirationClaim(value: Date().addingTimeInterval(3600)),
            iat: IssuedAtClaim(value: Date()),
            nonce: nonce
        )
        return try await keyCollection.sign(payload, kid: kid)
    }

    // MARK: - Helpers

    private static func base64ToBase64URL(_ base64: String) -> String {
        base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func formValue(_ key: String, from body: String) -> String? {
        body.split(separator: "&")
            .first { $0.hasPrefix("\(key)=") }
            .flatMap { pair -> String? in
                String(pair.dropFirst("\(key)=".count)).removingPercentEncoding
            }
    }
}
