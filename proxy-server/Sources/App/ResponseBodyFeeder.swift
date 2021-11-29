import HummingbirdCore
import NIOCore

final class ResponseBodyStreamFeeder: HBResponseBodyStreamer {
    let feeder: HBRequestBodyStreamer
    
    init(on eventLoop: EventLoop) {
        feeder = .init(eventLoop: eventLoop, maxSize: 1024*1024)
    }
    
    func feed(_ input: HBRequestBodyStreamer.FeedInput) {
        feeder.feed(input)
    }
    
    func read(on eventLoop: EventLoop) -> EventLoopFuture<HBResponseBody.StreamResult> {
        return feeder.consume(on: eventLoop).map {output in
            switch output {
            case .byteBuffer(let buffer):
                return .byteBuffer(buffer)
            case .end:
                return .end
            }
        }
    }
}
