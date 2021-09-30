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
import MultipartKit

struct RequestDecoder: HBRequestDecoder {
    let decoder = FormDataDecoder()

    func decode<T>(_ type: T.Type, from request: HBRequest) throws -> T where T: Decodable {
        if let contentType = request.headers["content-type"].first,
           HBMediaType(from: contentType)?.isType(.multipartForm) == true {
            return try self.decoder.decode(type, from: request)
        }
        throw HBHTTPError(.unsupportedMediaType)
    }
}
