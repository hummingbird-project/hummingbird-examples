//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Hummingbird

/// Type wrapping HTML code. Will convert to HBResponse that includes the correct
/// content-type header
struct HTML: HBResponseGenerator {
    let html: String

    public func response(from request: HBRequest, context: some HBBaseRequestContext) throws -> HBResponse {
        let buffer = context.allocator.buffer(string: self.html)
        return .init(status: .ok, headers: [.contentType: "text/html"], body: .init(byteBuffer: buffer))
    }
}
