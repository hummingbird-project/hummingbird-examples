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
import HummingbirdFluent
import Mustache

/// Redirects to login page if no user has been authenticated
struct RedirectMiddleware<Context: AuthRequestContext>: RouterMiddleware {
    let to: String
    func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Output
    ) async throws -> Response {
        if context.auth.has(User.self) {
            return try await next(request, context)
        } else {
            return .redirect(to: "\(self.to)?from=\(request.uri)", type: .found)
        }
    }
}

/// Serves HTML pages
struct WebController<Context: AuthRequestContext & RequestContext> {
    let fluent: Fluent
    let sessionAuthenticator: SessionAuthenticator<Context, UserRepository<Context>>
    let mustacheLibrary: MustacheLibrary
    let todosTemplate: MustacheTemplate
    let loginTemplate: MustacheTemplate
    let signupTemplate: MustacheTemplate
    let errorTemplate: MustacheTemplate

    init(mustacheLibrary: MustacheLibrary, fluent: Fluent, sessionAuthenticator: SessionAuthenticator<Context, UserRepository<Context>>) {
        // get the mustache templates from the library
        self.mustacheLibrary = mustacheLibrary
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

        self.fluent = fluent
        self.sessionAuthenticator = sessionAuthenticator
    }

    /// Add routes for webpages
    func addRoutes(to router: Router<Context>) {
        router.group()
            .add(middleware: ErrorPageMiddleware(errorTemplate: self.errorTemplate, mustacheLibrary: self.mustacheLibrary))
            .get("/login", use: self.login)
            .post("/login", use: self.loginDetails)
            .get("/signup", use: self.signup)
            .post("/signup", use: self.signupDetails)
            .add(middleware: self.sessionAuthenticator)
            .add(middleware: RedirectMiddleware(to: "/login"))
            .get("/", use: self.home)
    }

    struct Todo {
        let title: String
        let completed: Bool
    }

    /// Home page listing todos and with add todo UI
    @Sendable func home(request: Request, context: Context) async throws -> HTML {
        // get user and list of todos attached to user from database
        let user = try context.auth.require(User.self)
        let todos = try await user.$todos.get(on: self.fluent.db())
        // Render todos template and return as HTML
        let object: [String: Any] = [
            "name": user.name,
            "todos": todos,
        ]
        let html = self.todosTemplate.render(object, library: self.mustacheLibrary)
        return HTML(html: html)
    }

    /// Login page
    @Sendable func login(request: Request, context: Context) async throws -> HTML {
        let html = self.loginTemplate.render((), library: self.mustacheLibrary)
        return HTML(html: html)
    }

    struct LoginDetails: Decodable {
        let email: String
        let password: String
    }

    /// Login POST page
    @Sendable func loginDetails(request: Request, context: Context) async throws -> Response {
        let details = try await request.decode(as: LoginDetails.self, context: context)
        // check if user exists in the database and then verify the entered password
        // against the one stored in the database. If it is correct then login in user
        if let user = try await User.login(
            email: details.email,
            password: details.password,
            db: fluent.db()
        ) {
            // create session lasting 1 hour
            let cookie = try await self.sessionAuthenticator.sessionStorage.save(session: user.requireID(), expiresIn: .seconds(3600))
            // redirect to home page
            var response = Response.redirect(to: request.uri.queryParameters.get("from") ?? "/", type: .found)
            response.setCookie(cookie)
            return response
        } else {
            // login failed return login HTML with failed comment
            let html = self.loginTemplate.render(["failed": true], library: self.mustacheLibrary)
            var response = try HTML(html: html).response(from: request, context: context)
            response.status = .unauthorized
            return response
        }
    }

    struct SignupDetails: Decodable {
        let name: String
        let email: String
        let password: String
    }

    /// Signup page
    @Sendable func signup(request: Request, context: Context) async throws -> HTML {
        let html = self.signupTemplate.render((), library: self.mustacheLibrary)
        return HTML(html: html)
    }

    /// Signup POST page
    @Sendable func signupDetails(request: Request, context: Context) async throws -> Response {
        let details = try await request.decode(as: SignupDetails.self, context: context)
        do {
            // create new user
            _ = try await User.create(
                name: details.name,
                email: details.email,
                password: details.password,
                db: self.fluent.db()
            )
            // redirect to login page
            return .redirect(to: "/login", type: .found)
        } catch let error as HTTPError {
            // if user creation throws a conflict ie the email is already being used by
            // another user then return signup page with error message
            if error.status == .conflict {
                let html = self.signupTemplate.render(["failed": true], library: self.mustacheLibrary)
                return try HTML(html: html).response(from: request, context: context)
            } else {
                throw error
            }
        }
    }
}
