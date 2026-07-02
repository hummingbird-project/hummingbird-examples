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

import Configuration
import Hummingbird
import HummingbirdAuth
import Logging

/// Request context carrying the authenticated user identity.
typealias AppRequestContext = BasicAuthRequestContext<User>

///  Build application
/// - Parameters:
///   - reader: configuration reader
///   - keys: token keys; tests inject fixed keys, production generates fresh ones
func buildApplication(reader: ConfigReader, keys: TokenKeys? = nil) async throws -> some ApplicationProtocol {
    let logger = {
        var logger = Logger(label: "auth-jwe")
        logger.logLevel = reader.string(forKey: "log.level", as: Logger.Level.self, default: .info)
        return logger
    }()
    let router = try buildRouter(
        keys: keys ?? TokenKeys(),
        issuer: reader.string(forKey: "jwt.issuer", default: "auth-jwe-example"),
        audience: reader.string(forKey: "jwt.audience", default: "hummingbird-clients")
    )
    return Application(
        router: router,
        configuration: ApplicationConfiguration(reader: reader.scoped(to: "http")),
        logger: logger
    )
}

/// Build router
func buildRouter(keys: TokenKeys, issuer: String, audience: String) throws -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    router.addMiddleware {
        LogRequestsMiddleware(.info)
    }
    UserController(keys: keys, users: .demo(), issuer: issuer, audience: audience)
        .addRoutes(to: router.group("user"))
    // Routes behind encrypted-token authentication.
    router.group("auth")
        .add(middleware: JWEAuthenticator(keys: keys, audience: audience))
        .get("/") { _, context -> [String: String] in
            guard let user = context.identity else { throw HTTPError(.unauthorized) }
            return [
                "username": user.username,
                "email": user.email ?? "",
                "role": user.role ?? "",
            ]
        }
    return router
}
