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

struct WebController {
    func addRoutes(to router: HBRouterMethods) {
        router.get("/image/:index", use: ImageRequest.self)
        router.get("/image/:index/:count", use: ImagesRequest.self)
    }

    struct ImageRequest: HBRouteHandler {
        let index: Int
        let template: HBMustacheTemplate

        init(from request: HBRequest) throws {
            self.index = try request.parameters.require("index", as: Int.self)
            self.template = request.application.mustache.getTemplate(named: "image")!
        }

        func handle(request: HBRequest) -> HTML {
            struct RenderData {
                let index: Int
                let prev: Int?
                let next: Int?
            }
            let data = RenderData(index: index, prev: index > 0 ? self.index - 1 : nil, next: self.index + 1)
            let html = self.template.render(data)
            return .init(html: html)
        }
    }

    struct ImagesRequest: HBRouteHandler {
        let index: Int
        let count: Int
        let template: HBMustacheTemplate

        init(from request: HBRequest) throws {
            self.index = try request.parameters.require("index", as: Int.self)
            self.count = try request.parameters.require("count", as: Int.self)
            self.template = request.application.mustache.getTemplate(named: "images")!
        }

        func handle(request: HBRequest) -> HTML {
            struct RenderData {
                struct Image {
                    let index: Int
                }

                let images: [Image]
                let prev: Int?
                let next: Int?
                let count: Int
            }
            let images = (index..<(index + self.count)).map { RenderData.Image(index: $0) }
            let data = RenderData(
                images: images,
                prev: index - self.count >= 0 ? self.index - self.count : nil,
                next: self.index + self.count,
                count: self.count
            )
            let html = self.template.render(data)
            return .init(html: html)
        }
    }
}
