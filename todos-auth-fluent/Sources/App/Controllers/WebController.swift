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

import FluentKit
import Hummingbird
import HummingbirdAuth
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
struct WebController {
    let todosTemplate: HBMustacheTemplate
    let loginTemplate: HBMustacheTemplate
    let signupTemplate: HBMustacheTemplate
    let errorTemplate: HBMustacheTemplate

    init(mustacheLibrary: HBMustacheLibrary) {
        // get the mustache templates from the library
        guard let todosTemplate = mustacheLibrary.getTemplate(named: "todos"),
              let loginTemplate = mustacheLibrary.getTemplate(named: "login"),
              let signupTemplate = mustacheLibrary.getTemplate(named: "signup"),
              let errorTemplate = mustacheLibrary.getTemplate(named: "error")
        else {
            preconditionFailure("Failed to load mustache templates")
        }
        self.todosTemplate = todosTemplate
        self.loginTemplate = loginTemplate
        self.signupTemplate = signupTemplate
        self.errorTemplate = errorTemplate
    }

    /// Add routes for webpages
    func addRoutes(to router: HBRouterBuilder) {
        router.group()
            .add(middleware: ErrorPageMiddleware(template: self.errorTemplate))
            .get("/login", use: self.login)
            .post("/login", options: .editResponse, use: self.loginDetails)
            .get("/signup", use: self.signup)
            .post("/signup", use: self.signupDetails)
            .add(middleware: SessionAuthenticator())
            .add(middleware: RedirectMiddleware(to: "/login"))
            .get("/", use: self.home)
    }

    /// Home page listing todos and with add todo UI
    func home(request: HBRequest) async throws -> HTML {
        struct Todo {
            let title: String
            let completed: Bool
        }
        // get user and list of todos attached to user from database
        let user = try request.authRequire(User.self)
        let todos = try await user.$todos.get(on: request.db)
        // Render todos template and return as HTML
        let object: [String: Any] = [
            "name": user.name,
            "todos": todos,
        ]
        let html = self.todosTemplate.render(object)
        return HTML(html: html)
    }

    /// Login page
    func login(request: HBRequest) async throws -> HTML {
        let html = self.loginTemplate.render(())
        return HTML(html: html)
    }

    struct LoginDetails: Decodable {
        let email: String
        let password: String
    }

    /// Login POST page
    func loginDetails(request: HBRequest) async throws -> HBResponse {
        let details = try request.decode(as: LoginDetails.self)
        // check if user exists in the database and then verify the entered password
        // against the one stored in the database. If it is correct then login in user
        if let user = try await User.login(
            email: details.email,
            password: details.password,
            request: request
        ) {
            // create session lasting 1 hour
            try await request.session.save(session: user.requireID(), expiresIn: .minutes(60))
            // redirect to home page
            return .redirect(to: request.uri.queryParameters.get("from") ?? "/", type: .found)
        } else {
            // login failed return login HTML with failed comment
            let html = self.loginTemplate.render(["failed": true])
            return try HTML(html: html).response(from: request)
        }
    }

    struct SignupDetails: Decodable {
        let name: String
        let email: String
        let password: String
    }

    /// Signup page
    func signup(request: HBRequest) async throws -> HTML {
        let html = self.signupTemplate.render(())
        return HTML(html: html)
    }

    /// Signup POST page
    func signupDetails(request: HBRequest) async throws -> HBResponse {
        let details = try request.decode(as: SignupDetails.self)
        do {
            // create new user
            _ = try await User.create(
                name: details.name,
                email: details.email,
                password: details.password,
                request: request
            )
            // redirect to login page
            return .redirect(to: "/login", type: .found)
        } catch let error as HBHTTPError {
            // if user creation throws a conflict ie the email is already being used by
            // another user then return signup page with error message
            if error.status == .conflict {
                let html = self.signupTemplate.render(["failed": true])
                return try HTML(html: html).response(from: request)
            } else {
                throw error
            }
        }
    }
}
