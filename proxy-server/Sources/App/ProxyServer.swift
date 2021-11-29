import AsyncHTTPClient
import HummingbirdCore
import Logging
import NIO
import NIOHTTP1
import Network

public struct HTTPProxyServer: HBHTTPResponder {
    enum ProxyError: Error {
        case invalidURL
    }
    let targetServer: String
    let httpClient: HTTPClient
    public let logger: Logger
    
    public init(targetServer: String, httpClient: HTTPClient, logger: Logger) {
        self.targetServer = targetServer
        self.httpClient = httpClient
        self.logger = logger
    }

    public func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
        logger.info("\(request.head.uri)")
        do {
            let request = try request.ahcRequest(host: targetServer, on: context.eventLoop)
            let streamer = ResponseBodyStreamFeeder(on: context.eventLoop)
            let delegate = ResponseStreamingDelegate(on: context.eventLoop, streamer: streamer)
            _ = httpClient.execute(
                request: request,
                delegate: delegate,
                eventLoop: .delegateAndChannel(on: context.eventLoop),
                logger: logger
            )
            delegate.promise.futureResult.whenComplete { result in
                onComplete(result)
            }
        } catch {
            onComplete(.failure(ProxyError.invalidURL))
        }
    }
}

extension HBHTTPRequest {
    func ahcRequest(host: String, on eventLoop: EventLoop) throws -> HTTPClient.Request {
        switch self.body {
        case .byteBuffer(let buffer):
            return try HTTPClient.Request(
                url: host + self.head.uri,
                method: self.head.method,
                headers: self.head.headers,
                body: buffer.map { .byteBuffer($0) }
            )

        case .stream(let stream):
            return try HTTPClient.Request(
                url: host + self.head.uri,
                method: self.head.method,
                headers: self.head.headers,
                body: .stream(length: nil) { writer in
                    return stream.consumeAll(on: eventLoop) { byteBuffer in
                        writer.write(.byteBuffer(byteBuffer))
                    }
                }
            )
        }
    }
}

extension HTTPClient.Response {
    var hbResponse: HBHTTPResponse {
        return .init(
            head: .init(version: .init(major: 1, minor: 1), status: self.status, headers: self.headers),
            body: self.body.map { .byteBuffer($0) } ?? .empty
        )
    }
}
