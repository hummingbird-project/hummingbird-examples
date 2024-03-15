//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Hummingbird
import Mustache

struct HTML: ResponseGenerator {
    let html: String

    public func response(from request: Request, context: some BaseRequestContext) throws -> Response {
        let buffer = context.allocator.buffer(string: self.html)
        return .init(status: .ok, headers: [.contentType: "text/html"], body: .init(byteBuffer: buffer))
    }
}

struct WebController {
    let mustacheLibrary: MustacheLibrary

    func addRoutes(to router: Router<some RequestContext>) {
        router.get("/", use: self.input)
        router.post("/", use: self.post)
    }

    @Sendable func input(request: Request, context: some RequestContext) -> HTML {
        let html = self.mustacheLibrary.render((), withTemplate: "enter-details")!
        return HTML(html: html)
    }

    @Sendable func post(request: Request, context: some RequestContext) async throws -> HTML {
        let user = try await request.decode(as: User.self, context: context)
        let html = self.mustacheLibrary.render(user, withTemplate: "details-entered")!
        return HTML(html: html)
    }
}
