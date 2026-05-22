//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import FluentKit
import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdBasicAuth
import HummingbirdFluent

struct PostController: Sendable {
    typealias Context = AppRequestContext
    let fluent: Fluent

    /// Register routes under `router.group("posts")`:
    ///
    /// - `GET  /posts`      — public
    /// - `POST /posts`      — requires `posts:write` permission
    /// - `DELETE /posts/:id`— requires `admin` role OR `posts:delete` permission
    func addRoutes(to group: RouterGroup<Context>) {
        // Public: list all posts
        group.get(use: self.list)

        // Authenticated + posts:write permission: create a post
        group.group()
            .add(
                middleware: BasicAuthenticator { username, _ in
                    try await User.query(on: self.fluent.db())
                        .filter(\.$name == username)
                        .first()
                }
            )
            .add(middleware: AuthorizationPolicyMiddleware(PermissionPolicy(.postsWrite)))
            .post(use: self.create)

        // Authenticated + (admin role OR posts:delete permission): delete a post
        group.group(":id")
            .add(
                middleware: BasicAuthenticator { username, _ in
                    try await User.query(on: self.fluent.db())
                        .filter(\.$name == username)
                        .first()
                }
            )
            .add(
                middleware: AuthorizationPolicyMiddleware(
                    anyOf {
                        RolePolicy(.admin)
                        PermissionPolicy(.postsDelete)
                    }
                )
            )
            .delete(use: self.delete)
    }

    /// List all posts (public).
    func list(
        _ request: Request,
        context: Context
    ) async throws -> [PostResponse] {
        let posts = try await Post.query(on: self.fluent.db()).all()
        return posts.map { PostResponse(from: $0) }
    }

    /// Create a new post (requires `posts:write` permission).
    func create(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<PostResponse> {
        let body = try await request.decode(as: CreatePostRequest.self, context: context)
        let post = Post(title: body.title, body: body.body)
        try await post.save(on: self.fluent.db())
        return .init(status: .created, response: PostResponse(from: post))
    }

    /// Delete a post by ID (requires `admin` role OR `posts:delete` permission).
    func delete(
        _ request: Request,
        context: Context
    ) async throws -> HTTPResponse.Status {
        let id = try context.parameters.require("id", as: UUID.self)
        let db = self.fluent.db()
        guard let post = try await Post.find(id, on: db) else {
            throw HTTPError(.notFound)
        }
        try await post.delete(on: db)
        return .ok
    }
}
