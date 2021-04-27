//
//  ResponseGenerators.swift
//  ios-image-server
//
//  Created by Adam Fowler on 27/04/2021.
//

import Foundation
import Hummingbird

struct HTML: HBResponseGenerator {
    let html: String
    func response(from request: HBRequest) throws -> HBResponse {
        let body = request.allocator.buffer(string: html)
        return .init(status: .ok, headers: ["content-type": HBMediaType.textHtml.description], body: .byteBuffer(body))
    }
}

struct ImageData: HBResponseGenerator {
    let data: Data

    func response(from request: HBRequest) throws -> HBResponse {
        let body = request.allocator.buffer(data: data)
        return .init(status: .ok, headers: ["content-type": HBMediaType.imageJpeg.description], body: .byteBuffer(body))
    }
}
