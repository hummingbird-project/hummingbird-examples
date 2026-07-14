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

import Foundation
import JWSETKit

/// The server's token keys.
///
/// - `signing` (ES256) authenticates the claims — proves the server issued them.
/// - `encryption` (P-256, ECDH-ES) makes the claims confidential — only the
///   server can read them back. Together they form a *nested JWT*
///   (RFC 7519 §11.2): sign first, then encrypt.
struct TokenKeys {
    let signing: JSONWebECPrivateKey
    let encryption: JSONWebECPrivateKey
    let signingPublicKey: JSONWebECPublicKey
    let encryptionPublicKey: JSONWebECPublicKey

    /// Loads the fixed demo keys so tokens remain valid across server restarts.
    /// A real deployment would load persisted keys from a secret store.
    init() throws {
        try self.init(
            signing: JSONWebECPrivateKey(from: Self.demoSigningJWK),
            encryption: JSONWebECPrivateKey(from: Self.demoEncryptionJWK)
        )
    }

    init(signing: JSONWebECPrivateKey, encryption: JSONWebECPrivateKey) {
        self.signing = signing
        self.encryption = encryption
        self.signingPublicKey = signing.publicKey
        self.encryptionPublicKey = encryption.publicKey
    }

    /// Fresh random keys, used by tests.
    static func random() throws -> TokenKeys {
        try .init(
            signing: JSONWebECPrivateKey(curve: .p256),
            encryption: JSONWebECPrivateKey(curve: .p256)
        )
    }

    /// Demo keys — publicly committed, for local development only.
    private static let demoSigningJWK = #"""
    {"kty":"EC","crv":"P-256","d":"08xXj5z1YwjRg2dTwVQPtSyB1qVar1o2vFn-Gq6CK8Y","x":"NtLVcpzdKun_z4uU6ivGZWLjNFzAsvyAw5RpFAZ7ro8","y":"XVqmjCmdHrpn5wlF3i-7WfihNgopIyFTKO2aNjOODIY"}
    """#
    private static let demoEncryptionJWK = #"""
    {"kty":"EC","crv":"P-256","d":"MwDVHxciv7I4Ay1r2HhcDL1cpypxjjAuyKpG0goqnNc","x":"6vvVOB_gfJzsJSr2gr0ma5rBUX58a5L81qwqu3sI7O8","y":"VzR-RImb8eAX4ua7Ua1CPUtVZ-O-pVOXczXB9TZJQOA"}
    """#
}

extension JSONWebECPrivateKey {
    fileprivate init(from jwk: String) throws {
        self = try JSONDecoder().decode(JSONWebECPrivateKey.self, from: Data(jwk.utf8))
    }
}
