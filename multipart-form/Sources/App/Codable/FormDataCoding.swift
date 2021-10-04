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
import MultipartKit
import NIOFoundationCompat

extension FormDataEncoder: HBResponseEncoder {
    /// Extend JSONEncoder to support encoding `HBResponse`'s. Sets body and header values
    /// - Parameters:
    ///   - value: Value to encode
    ///   - request: Request used to generate response
    public func encode<T: Encodable>(_ value: T, from request: HBRequest) throws -> HBResponse {
        var buffer = request.allocator.buffer(capacity: 0)

        let boundary = "----HBFormBoundary" + String(base32Encoding: (0..<4).map { _ in UInt8.random(in: 0...255) })
        try self.encode(value, boundary: boundary, into: &buffer)
        return HBResponse(
            status: .ok,
            headers: ["content-type": "multipart/form-data; boundary=\(boundary)"],
            body: .byteBuffer(buffer)
        )
    }
}

extension FormDataDecoder: HBRequestDecoder {
    /// Extend JSONDecoder to decode from `HBRequest`.
    /// - Parameters:
    ///   - type: Type to decode
    ///   - request: Request to decode from
    public func decode<T: Decodable>(_ type: T.Type, from request: HBRequest) throws -> T {
        guard let buffer = request.body.buffer,
              let contentType = request.headers["content-type"].first,
              let mediaType = HBMediaType(from: contentType),
              let parameter = mediaType.parameter,
              parameter.name == "boundary" else {
                  throw HBHTTPError(.badRequest)
              }
        return try self.decode(T.self, from: buffer, boundary: parameter.value)
    }
}
