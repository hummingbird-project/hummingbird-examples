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

/// Database description of a blog post
final class Post: Model, @unchecked Sendable {
    static let schema = "post"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @Field(key: "body")
    var body: String

    init() {}

    init(id: UUID? = nil, title: String, body: String) {
        self.id = id
        self.title = title
        self.body = body
    }
}

// MARK: - Request / Response types

/// Request body for creating a new post
struct CreatePostRequest: Decodable {
    let title: String
    let body: String
}

/// Post encoded into an HTTP response
struct PostResponse: ResponseCodable {
    let id: UUID?
    let title: String
    let body: String

    init(from post: Post) {
        self.id = post.id
        self.title = post.title
        self.body = post.body
    }
}
