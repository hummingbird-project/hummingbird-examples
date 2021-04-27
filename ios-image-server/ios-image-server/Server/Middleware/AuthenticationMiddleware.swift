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

import ExtrasBase64
import Hummingbird
import HummingbirdFoundation

struct AuthenticationMiddleware: HBMiddleware {
    let token: String

    init() {
        let bytes = (1...4).map { _ in UInt8.random(in: 0..<255) }
        self.token = String(base32Encoding: bytes)
    }

    func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        guard request.cookies["token"]?.value == self.token else {
            do {
                // redirect to index page if unauthenticated
                let response = try HTML(html: #"<html><head><meta http-equiv="refresh" content="0; url=/" /></head></html>"#).response(from: request)
                response.status = .unauthorized
                return request.success(response)
            } catch {
                return request.failure(error)
            }
        }
        return next.respond(to: request)
    }
}
