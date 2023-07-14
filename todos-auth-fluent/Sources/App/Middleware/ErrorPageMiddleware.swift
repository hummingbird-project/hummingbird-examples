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

/// Generate an HTML page for a thrown error
struct ErrorPageMiddleware: HBMiddleware {
    let template: HBMustacheTemplate

    func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        return next.respond(to: request).flatMapErrorThrowing { error in
            // if error is thrown from further down the middlware chain then either return
            // page with status code and message or a 501 with a description of the thrown error
            let values: [String: Any]
            let status: HTTPResponseStatus
            if let error = error as? HBHTTPError {
                status = error.status
                values = [
                    "statusCode": error.status,
                    "message": error.body ?? "",
                ]
            } else {
                status = .internalServerError
                values = [
                    "statusCode": HTTPResponseStatus.internalServerError,
                    "message": "\(error)",
                ]
            }
            // render HTML and return
            let html = self.template.render(values)
            var response = try HTML(html: html).response(from: request)
            response.status = status
            return response
        }
    }
}
