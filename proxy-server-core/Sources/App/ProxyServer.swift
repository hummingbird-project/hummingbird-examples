import AsyncHTTPClient
import HummingbirdCore
import Logging
import NIO
import NIOHTTP1

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
        self.logger.info("\(request.head.uri)")
        do {
            // create request
            let request = try request.ahcRequest(host: self.targetServer, eventLoop: context.eventLoop)
            // create response body streamer
            let streamer = HBByteBufferStreamer(eventLoop: context.eventLoop, maxSize: 2048 * 1024)
            // delegate for streaming bytebuffers from AsyncHTTPClient
            let delegate = StreamingResponseDelegate(on: context.eventLoop, streamer: streamer)
            // execute request
            _ = self.httpClient.execute(
                request: request,
                delegate: delegate,
                eventLoop: .delegateAndChannel(on: context.eventLoop),
                logger: self.logger
            )
            // when delegate receives header then single completion
            delegate.responsePromise.futureResult.whenComplete { result in
                onComplete(result)
            }
        } catch {
            onComplete(.failure(ProxyError.invalidURL))
        }
    }
}

extension HBHTTPRequest {
    /// create AsyncHTTPClient request from Hummingbird Request
    func ahcRequest(host: String, eventLoop: EventLoop) throws -> HTTPClient.Request {
        var headers = self.head.headers
        headers.remove(name: "host")
        switch self.body {
        case .byteBuffer(let buffer):
            return try HTTPClient.Request(
                url: host + self.head.uri,
                method: self.head.method,
                headers: headers,
                body: buffer.map { .byteBuffer($0) }
            )

        case .stream(let stream):
            let contentLength = self.head.headers["content-length"].first.map { Int($0) } ?? nil
            return try HTTPClient.Request(
                url: host + self.head.uri,
                method: self.head.method,
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
