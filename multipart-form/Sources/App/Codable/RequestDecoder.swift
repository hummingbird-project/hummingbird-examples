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

struct MultipartRequestDecoder: RequestDecoder {
    func decode<T>(_ type: T.Type, from request: Request, context: some RequestContext) async throws -> T where T: Decodable {
        let decoder = FormDataDecoder()
        return try await decoder.decode(type, from: request, context: context)
    }
}
