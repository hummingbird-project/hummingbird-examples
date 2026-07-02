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

    init() throws {
        var signing = try JSONWebECPrivateKey(curve: .p256)
        signing.populateKeyIdIfNeeded()
        var encryption = try JSONWebECPrivateKey(curve: .p256)
        encryption.populateKeyIdIfNeeded()
        self.signing = signing
        self.encryption = encryption
        self.signingPublicKey = signing.publicKey
        self.encryptionPublicKey = encryption.publicKey
    }

    /// Assemble from existing keys (used by tests to mix-and-match).
    init(signing: JSONWebECPrivateKey, encryption: JSONWebECPrivateKey) {
        self.signing = signing
        self.encryption = encryption
        self.signingPublicKey = signing.publicKey
        self.encryptionPublicKey = encryption.publicKey
    }
}
