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

import Foundation
import Hummingbird

/// Generate `HBResponse` with correct headers for HTML data
struct HTML: HBResponseGenerator {
    let html: String
    func response(from request: HBRequest) throws -> HBResponse {
        let body = request.allocator.buffer(string: self.html)
        return .init(status: .ok, headers: ["content-type": HBMediaType.textHtml.description], body: .byteBuffer(body))
    }
}

/// Generate `HBResponse` with correct headers for Jpeg data
struct JpegData: HBResponseGenerator {
    let data: Data
    func response(from request: HBRequest) throws -> HBResponse {
        let body = request.allocator.buffer(data: self.data)
        return .init(status: .ok, headers: ["content-type": HBMediaType.imageJpeg.description], body: .byteBuffer(body))
    }
}
