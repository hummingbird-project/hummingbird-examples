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

struct LoginController {
    func addRoutes(to router: HBRouter) {
        router.get("/", use: self.index)
        router.post("/", use: LoginHandler.self)
    }

    func index(_ request: HBRequest) -> HTML {
        let html = request.application.mustache.getTemplate(named: "login")!.render(())
        return .init(html: html)
    }

    struct LoginHandler: HBRouteHandler {
        struct Input: Decodable {
            let token: String
        }

        let input: Input
        init(from request: HBRequest) throws {
            self.input = try request.decode(as: Input.self)
        }

        func handle(request: HBRequest) -> HTML {
            request.response.setCookie(.init(name: "token", value: self.input.token))
            return .init(html: #"<html><head><meta http-equiv="refresh" content="0; url=/image/0/16" /></head></html>"#)
        }
    }
}
