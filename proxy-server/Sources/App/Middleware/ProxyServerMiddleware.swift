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

import AsyncHTTPClient
import Hummingbird
import Logging

/// Middleware forwarding requests onto another server
public struct HBProxyServerMiddleware: HBMiddleware {
    let httpClient: HTTPClient
    let targetServer: String
    
    public init(httpClient: HTTPClient, targetServer: String) {
        self.httpClient = httpClient
        self.targetServer = targetServer
    }
    
    public func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        request.logger.info("\(request.uri)")

        do {
            // create request
            let ahcRequest = try request.ahcRequest(host: targetServer, eventLoop: request.eventLoop)
            // create response body streamer
            let streamer = HBByteBufferStreamer(eventLoop: request.eventLoop, maxSize: 2048*1024)
            // delegate for streaming bytebuffers from AsyncHTTPClient
            let delegate = StreamingResponseDelegate(on: request.eventLoop, streamer: streamer)
            // execute request
            _ = httpClient.execute(
                request: ahcRequest,
                delegate: delegate,
                eventLoop: .delegateAndChannel(on: request.eventLoop),
                logger: request.logger
            )
            // when delegate receives header then signal completion
            return delegate.responsePromise.futureResult
        } catch {
            return request.failure(.badRequest)
        }
    }
}

extension HBRequest {
    /// create AsyncHTTPClient request from Hummingbird Request
    func ahcRequest(host: String, eventLoop: EventLoop) throws -> HTTPClient.Request {
        var headers = self.headers
        headers.remove(name: "host")
        switch self.body {
        case .byteBuffer(let buffer):
            return try HTTPClient.Request(
                url: host + self.uri.description,
                method: self.method,
                headers: headers,
                body: buffer.map { .byteBuffer($0) }
            )

        case .stream(let stream):
            let contentLength = self.headers["content-length"].first.map { Int($0) } ?? nil
            return try HTTPClient.Request(
                url: host + self.uri.description,
                method: self.method,
                headers: headers,
                body: .stream(length: contentLength) { writer in
                    return stream.consumeAll(on: eventLoop) { byteBuffer in
                        writer.write(.byteBuffer(byteBuffer))
                    }
                }
            )
        }
    }
}
