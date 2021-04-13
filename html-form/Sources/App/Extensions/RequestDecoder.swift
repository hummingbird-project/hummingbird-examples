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
import HummingbirdFoundation

struct RequestDecoder: HBRequestDecoder {
    let decoder = URLEncodedFormDecoder()

    func decode<T>(_ type: T.Type, from request: HBRequest) throws -> T where T: Decodable {
        if request.headers["content-type"].first == "application/x-www-form-urlencoded" {
            return try self.decoder.decode(type, from: request)
        }
        throw HBHTTPError(.unsupportedMediaType)
    }
}
