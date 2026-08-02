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
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Hummingbird
import HummingbirdAuth
import HummingbirdOIDC

protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
}

/// Read a required environment variable, crashing with a clear message if absent.
private func requireEnv(_ key: String) -> String {
    guard let value = ProcessInfo.processInfo.environment[key], !value.isEmpty else {
        fatalError("Required environment variable '\(key)' is not set")
    }
    return value
}

func buildApplication(
    _ args: AppArguments,
    configuration: ApplicationConfiguration,
    httpClient: HTTPClient = .shared,
    oidcOverride: OIDC? = nil
) async throws -> some ApplicationProtocol {
    let persist = MemoryPersistDriver()

    let oidc: OIDC
    if let override = oidcOverride {
        oidc = override
    } else {
        let redirectURI = requireEnv("OIDC_REDIRECT_URI")
        // Derive the app base URL from the redirect URI for post-logout redirect
        let appBaseURL = redirectURI.components(separatedBy: "/auth/").first ?? redirectURI
        let oidcConfig = OIDCConfiguration(
            clientID: requireEnv("OIDC_CLIENT_ID"),
            clientSecret: ProcessInfo.processInfo.environment["OIDC_CLIENT_SECRET"],
            redirectURI: redirectURI,
            scopes: ["openid", "profile", "email"],
            issuer: requireEnv("OIDC_ISSUER"),
            postLogoutRedirectURI: appBaseURL
        )
        oidc = OIDC(
            configuration: oidcConfig,
            stateStore: PersistDriverStateStore(persist),
            httpClient: httpClient
        )
    }

    let router = Router(context: AppRequestContext.self)
    router.addMiddleware {
        LogRequestsMiddleware(.debug)
        SessionMiddleware(storage: persist)
    }

    HomeController(oidc: oidc).addRoutes(to: router.group(""))
    AuthController(oidc: oidc).addRoutes(to: router.group("auth"))
    MeController(oidc: oidc).addRoutes(to: router.group(""))

    var app = Application(
        router: router,
        configuration: configuration
    )
    app.addServices(persist)
    return app
}
