//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Hummingbird
import WebAuthn

/// Application arguments protocol. We use a protocol so we can call
/// `HBApplication.configure` inside Tests as well as in the App executable.
/// Any variables added here also have to be added to `App` in App.swift and
/// `TestArguments` in AppTest.swift
public protocol AppArguments {}

extension HBApplication {
    /// configure your application
    /// add middleware
    /// setup the encoder/decoder
    /// add your routes
    func configure(_: AppArguments) throws {
        self.webauthn = .init(
            config: WebAuthnConfig(
                relyingPartyDisplayName: "Hummingbird WebAuthn example",
                relyingPartyID: "hummingbird.com",
                relyingPartyOrigin: "https://hummingbird.com",
                timeout: 600
            )
        )

        self.router.get("/health") { _ -> HTTPResponseStatus in
            return .ok
        }
    }
}

extension HBRequest {
    var webauthn: WebAuthnManager { return self.application.webauthn }
}
