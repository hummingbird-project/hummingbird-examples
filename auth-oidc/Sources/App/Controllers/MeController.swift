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

import Hummingbird
import HummingbirdAuth
import HummingbirdOIDC

struct MeController {
    typealias Context = AppRequestContext

    struct MeResponse: ResponseCodable {
        let subject: String
        let issuer: String
        let name: String?
        let email: String?
    }

    func addRoutes(to group: RouterGroup<Context>) {
        group
            .add(middleware: OIDCSessionAuthenticator(oidc: oidc))
            .get("me", use: self.me)
    }

    let oidc: OIDC

    @Sendable func me(_ request: Request, _ context: Context) throws -> MeResponse {
        let identity = try context.requireIdentity()
        return MeResponse(
            subject: identity.subject,
            issuer: identity.issuer,
            name: identity.claims.name,
            email: identity.claims.email
        )
    }
}
