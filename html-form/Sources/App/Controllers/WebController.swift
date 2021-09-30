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
import HummingbirdMustache

struct HTML: HBResponseGenerator {
    let html: String

    public func response(from request: HBRequest) throws -> HBResponse {
        let buffer = request.allocator.buffer(string: self.html)
        return .init(status: .ok, headers: ["content-type": "text/html"], body: .byteBuffer(buffer))
    }
}

struct WebController {
    let mustacheLibrary: HBMustacheLibrary

    func input(request: HBRequest) -> HTML {
        let html = mustacheLibrary.render((), withTemplate: "enter-details")!
        return HTML(html: html)
    }

    func post(request: HBRequest) throws -> HTML {
        guard let user = try? request.decode(as: User.self) else { throw HBHTTPError(.badRequest) }
        let html = mustacheLibrary.render(user, withTemplate: "details-entered")!
        return HTML(html: html)
    }
}
