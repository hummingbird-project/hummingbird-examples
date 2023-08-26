//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Hummingbird
import HummingbirdMustache

/// Redirects to login page if no user has been authenticated
struct RedirectMiddleware: HBMiddleware {
    let to: String
    func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        if request.authHas(User.self) {
            return next.respond(to: request)
        } else {
            return request.eventLoop.makeSucceededFuture(.redirect(to: "\(self.to)?from=\(request.uri)", type: .found))
        }
    }
}

/// Serves HTML pages
struct HTMLController {
    let homeTemplate: HBMustacheTemplate

    init(mustacheLibrary: HBMustacheLibrary) {
        // get the mustache templates from the library
        guard let homeTemplate = mustacheLibrary.getTemplate(named: "home")
        else {
            preconditionFailure("Failed to load mustache templates")
        }
        self.homeTemplate = homeTemplate
    }

    /// Add routes for webpages
    func addRoutes(to router: HBRouterBuilder) {
        router.group()
            .add(middleware: WebAuthnSessionAuthenticator())
            .add(middleware: RedirectMiddleware(to: "/login.html"))
            .get("/", use: self.home)
    }

    /// Home page listing todos and with add todo UI
    func home(request: HBRequest) async throws -> HTML {
        // get user
        let user = try request.authRequire(User.self)
        // Render home template and return as HTML
        let object: [String: Any] = [
            "name": user.username,
        ]
        let html = self.homeTemplate.render(object)
        return HTML(html: html)
    }
}
