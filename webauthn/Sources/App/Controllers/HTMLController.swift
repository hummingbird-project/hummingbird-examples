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
import HummingbirdAuth
import HummingbirdFluent
import HummingbirdRouter
import Mustache

/// Redirects to login page if no user has been authenticated
struct RedirectMiddleware<Context: AuthRequestContext>: RouterMiddleware {
    let to: String
    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        // check if authenticated
        if context.auth.has(User.self) {
            return try await next(request, context)
        } else {
            // if not authenticated then redirect to login page
            return .redirect(to: "\(self.to)?from=\(request.uri)", type: .found)
        }
    }
}

/// Serves HTML pages
struct HTMLController {
    typealias Context = WebAuthnRequestContext

    let homeTemplate: MustacheTemplate
    let fluent: Fluent
    let webAuthnSessionAuthenticator: SessionAuthenticator<Context, UserSessionClosure<WebAuthnSession, Context, User>>

    init(
        mustacheLibrary: MustacheLibrary,
        fluent: Fluent,
        webAuthnSessionAuthenticator: SessionAuthenticator<Context, UserSessionClosure<WebAuthnSession, Context, User>>
    ) {
        // get the mustache templates from the library
        guard let homeTemplate = mustacheLibrary.getTemplate(named: "home")
        else {
            preconditionFailure("Failed to load mustache templates")
        }
        self.homeTemplate = homeTemplate
        self.fluent = fluent
        self.webAuthnSessionAuthenticator = webAuthnSessionAuthenticator
    }

    // return Route for home page
    var endpoints: some RouterMiddleware<Context> {
        Get("/") {
            self.webAuthnSessionAuthenticator
            RedirectMiddleware(to: "/login.html")
            self.home
        }
    }

    /// Home page listing todos and with add todo UI
    @Sendable func home(request: Request, context: Context) async throws -> HTML {
        // get user
        let user = try context.auth.require(User.self)
        // Render home template and return as HTML
        let object: [String: Any] = [
            "name": user.username,
        ]
        let html = self.homeTemplate.render(object)
        return HTML(html: html)
    }
}
