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

struct ErrorPageMiddleware: HBMiddleware {
    let template: HBMustacheTemplate

    func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        return next.respond(to: request).flatMapErrorThrowing { error in
            let values: [String: Any]
            if let error = error as? HBHTTPError {
                values = [
                    "statusCode": error.status,
                    "message": error.body ?? "",
                ]
            } else {
                values = [
                    "statusCode": HTTPResponseStatus.internalServerError,
                    "message": "\(error)",
                ]
            }
            let html = self.template.render(values) // emustacheLibrary.render(values, withTemplate: "error")!
            return try HTML(html: html).response(from: request)
        }
    }
}
