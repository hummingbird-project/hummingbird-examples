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
import HummingbirdCore
import Logging
import NIOHTTP1
import NIOHTTPTypesHTTP1

/// Middleware forwarding requests onto another server
struct ProxyServerMiddleware: RouterMiddleware {
    typealias Context = ProxyRequestContext
    struct Proxy: Sendable {
        let location: String
        let target: String

        init(location: String, target: String) {
            self.location = location.dropSuffix("/")
            self.target = target.dropSuffix("/")
        }
    }

    let httpClient: HTTPClient
    let proxy: Proxy

    init(httpClient: HTTPClient, proxy: Proxy) {
        self.httpClient = httpClient
        self.proxy = proxy
    }

    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        guard let response = try await forward(request: request, to: proxy, context: context) else {
            return try await next(request, context)
        }
        return response
    }

    func forward(request: Request, to proxy: Proxy, context: Context) async throws -> Response? {
        guard request.uri.description.hasPrefix(proxy.location) else { return nil }
        let newURI = request.uri.description.dropFirst(proxy.location.count)
        guard newURI.first == nil || newURI.first == "/" else { return nil }

        // Construct request
        var clientRequest = HTTPClientRequest(url: "\(proxy.target)\(newURI)")
        clientRequest.method = .init(request.method)
        clientRequest.headers = .init(request.headers)
        if let remoteAddress = context.remoteAddress {
            switch context.remoteAddress {
            case .v4:
                clientRequest.headers.add(name: "Forwarded", value: "for=\(remoteAddress.ipAddress!)")
            case .v6:
                clientRequest.headers.add(name: "Forwarded", value: "for=\"[\(remoteAddress.ipAddress!)]\"")
            default:
                break
            }
        }
        // extract length from content-length header
        let contentLength = if let header = request.headers[.contentLength], let value = Int(header) {
            HTTPClientRequest.Body.Length.known(value)
        } else {
            HTTPClientRequest.Body.Length.unknown
        }
        clientRequest.body = .stream(
            request.body,
            length: contentLength
        )

        do {
            // execute request
            let response = try await self.httpClient.execute(clientRequest, timeout: .seconds(60))
            // construct response
            return Response(
                status: .init(code: Int(response.status.code), reasonPhrase: response.status.reasonPhrase),
                headers: .init(response.headers, splitCookie: false),
                body: .init(asyncSequence: response.body)
            )
        } catch {
            context.logger.error("Client error: \(error)")
            throw error
        }
    }
}

extension String {
    fileprivate func dropSuffix(_ suffix: String) -> String {
        if hasSuffix(suffix) {
            return String(self.dropLast(suffix.count))
        } else {
            return self
        }
    }
}
