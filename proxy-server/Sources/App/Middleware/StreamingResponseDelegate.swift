import AsyncHTTPClient
import Hummingbird
import NIOHTTP1

final class StreamingResponseDelegate: HTTPClientResponseDelegate {
    typealias Response = HBResponse

    enum State {
        case idle
        case head(HTTPResponseHead)
        case error(Error)
    }

    let streamer: HBByteBufferStreamer
    let responsePromise: EventLoopPromise<Response>
    let eventLoop: EventLoop
    var state: State

    init(on eventLoop: EventLoop, streamer: HBByteBufferStreamer) {
        self.eventLoop = eventLoop
        self.streamer = streamer
        self.responsePromise = eventLoop.makePromise()
        self.state = .idle
    }

    func didReceiveHead(task: HTTPClient.Task<Response>, _ head: HTTPResponseHead) -> EventLoopFuture<Void> {
        switch self.state {
        case .idle:
            let response = Response(status: head.status, headers: head.headers, body: .stream(streamer))
            responsePromise.succeed(response)
            self.state = .head(head)
        case .error:
            break
        default:
            preconditionFailure("Unexpected state \(state)")
        }
        return eventLoop.makeSucceededVoidFuture()
    }

    func didReceiveBodyPart(task: HTTPClient.Task<Response>, _ buffer: ByteBuffer) -> EventLoopFuture<Void> {
        switch self.state {
        case .head:
            return streamer.feed(buffer: buffer)
        case .error:
            break
        default:
            preconditionFailure("Unexpected state \(state)")
        }
        return eventLoop.makeSucceededVoidFuture()
    }

    func didFinishRequest(task: HTTPClient.Task<Response>) throws -> HBResponse {
        switch self.state {
        case .head(let head):
            self.state = .idle
            self.streamer.feed(.end)
            return .init(status: head.status, headers: head.headers, body: .stream(streamer))
        case .error(let error):
            throw error
        default:
            preconditionFailure("Unexpected state \(state)")
        }
    }

    func didReceiveError(task: HTTPClient.Task<Response>, _ error: Error) {
        streamer.feed(.error(error))
        self.state = .error(error)
    }
}
