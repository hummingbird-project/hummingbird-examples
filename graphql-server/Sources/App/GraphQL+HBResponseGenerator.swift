import GraphQL
import Foundation
import Hummingbird

extension GraphQLResult: HBResponseGenerator {
    public func response(from request: HBRequest) throws -> HBResponse {
        let encoded = try JSONEncoder().encode(self)
        let buffer = request.allocator.buffer(data: encoded)
        return HBResponse(status: .ok,
                          headers: ["contnet-type" : "application/json; charset=utf-8"],
                          body: .byteBuffer(buffer))
    }
}
