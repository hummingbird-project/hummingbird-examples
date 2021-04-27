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

/// Holds one route for loading images
/// GET /assets/:index will return a Jpeg version of image with index
struct ImageController {
    func addRoutes(to router: HBRouterMethods) {
        router.get("/assets/:index", use: GetImageHandler.self)
    }

    /// Get image route hander
    struct GetImageHandler: HBRouteHandler {
        let index: Int
        let width: Double
        let height: Double

        init(from request: HBRequest) throws {
            self.index = try request.parameters.require("index", as: Int.self)
            self.width = request.uri.queryParameters.get("width", as: Double.self) ?? 1024
            self.height = request.uri.queryParameters.get("height", as: Double.self) ?? 1024
        }

        func handle(request: HBRequest) -> EventLoopFuture<JpegData> {
            let promise = request.eventLoop.makePromise(of: JpegData.self)
            request.application.photoLibrary.loadPhoto(index: self.index, targetSize: .init(width: self.width, height: self.height)) { result in
                promise.completeWith(result.map { .init(data: $0) })
            }
            return promise.futureResult
        }
    }
}
