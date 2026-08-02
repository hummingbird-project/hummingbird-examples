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
import HummingbirdOIDC

struct AuthController {
    typealias Context = AppRequestContext

    let oidc: OIDC

    func addRoutes(to group: RouterGroup<Context>) {
        group.get("login", use: oidc.loginHandler)
        group.get("callback", use: oidc.callbackSessionHandler)
        // POST-only: GET logout is vulnerable to CSRF-forced logout attacks.
        // Trigger from a <form method="post" action="/auth/logout"> in your UI.
        group.post("logout", use: oidc.logoutHandler)
    }
}
