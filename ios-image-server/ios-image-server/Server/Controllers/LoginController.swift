//
//  LoginController.swift
//  ios-image-server
//
//  Created by Adam Fowler on 27/04/2021.
//

import Hummingbird
import HummingbirdMustache

struct LoginController {
    func addRoutes(to router: HBRouter) {
        router.get("/", use: index)
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
