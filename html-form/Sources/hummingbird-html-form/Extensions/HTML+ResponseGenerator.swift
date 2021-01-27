import Plot
import Hummingbird

extension HTML: HBResponseGenerator {
    public func response(from request: HBRequest) throws -> HBResponse {
        let html = self.render()
        let buffer = request.allocator.buffer(string: html)
        return .init(status: .ok, headers: ["content-type": "text/html"], body: .byteBuffer(buffer))
    }
}
