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

struct HTML: HBResponseGenerator {
    let html: String

    public func response(from request: HBRequest) throws -> HBResponse {
        let buffer = request.allocator.buffer(string: self.html)
        return .init(status: .ok, headers: ["content-type": "text/html"], body: .byteBuffer(buffer))
    }
}

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

struct WebController {
    let mustacheLibrary: HBMustacheLibrary

    /// Add routes for webpages
    func addRoutes(to router: HBRouterBuilder) {
        router.group()
            .get("/login", use: self.login)
            .post("/login", options: .editResponse, use: self.loginDetails)
            .get("/signup", use: self.signup)
            .post("/signup", use: self.signupDetails)
            .add(middleware: SessionAuthenticator())
            .add(middleware: RedirectMiddleware(to: "/login"))
            .get("/", use: self.home)
    }

    func home(request: HBRequest) async throws -> HTML {
        struct Todo {
            let title: String
            let completed: Bool
        }
        let user = try request.authRequire(User.self)
        let todos = try await user.$todos.get(on: request.db)
        let object: [String: Any] = [
            "name": user.name,
            "todos": todos,
        ]
        let html = self.mustacheLibrary.render(object, withTemplate: "todos")!
        return HTML(html: html)
    }

    func login(request: HBRequest) async throws -> HTML {
        let html = self.mustacheLibrary.render((), withTemplate: "login")!
        return HTML(html: html)
    }

    struct LoginDetails: Decodable {
        let email: String
        let password: String
    }

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
            return .redirect(to: request.uri.queryParameters.get("from") ?? "/", type: .found)
        } else {
            let html = self.mustacheLibrary.render(["failed": true], withTemplate: "login")!
            return try HTML(html: html).response(from: request)
        }
    }

    struct SignupDetails: Decodable {
        let name: String
        let email: String
        let password: String
    }

    func signup(request: HBRequest) async throws -> HTML {
        let html = self.mustacheLibrary.render((), withTemplate: "signup")!
        return HTML(html: html)
    }

    func signupDetails(request: HBRequest) async throws -> HBResponse {
        let details = try request.decode(as: SignupDetails.self)
        do {
            _ = try await User.create(
                name: details.name,
                email: details.email,
                password: details.password,
                request: request
            )
            return .redirect(to: "/login", type: .found)
        } catch let error as HBHTTPError {
            if error.status == .conflict {
                let html = self.mustacheLibrary.render(["failed": true], withTemplate: "signup")!
                return try HTML(html: html).response(from: request)
            } else {
                throw error
            }
        } catch {
            print("\(error)")
            throw error
        }
    }
}
