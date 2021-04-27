//
//  WebController.swift
//  ios-image-server
//
//  Created by Adam Fowler on 27/04/2021.
//

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
            let data = RenderData(index: index, prev: index > 0 ? index-1: nil , next: index + 1)
            let html = template.render(data)
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
            let images = (index..<(index+count)).map { RenderData.Image(index: $0) }
            let data = RenderData(
                images: images,
                prev: index - count >= 0 ? index - count: nil ,
                next: index + count,
                count: count
            )
            let html = template.render(data)
            return .init(html: html)
        }
    }
}
