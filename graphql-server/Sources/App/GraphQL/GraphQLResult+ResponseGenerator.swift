import GraphQL
import HTTPTypes
import Hummingbird
import NIOFoundationCompat

extension GraphQLResult {
    public func response(from _: Request, context _: some RequestContext) throws -> Response {
        let encoder = GraphQLJSONEncoder()
        let data = try encoder.encode(self)
        return Response(
            status: .ok,
            headers: [
                .contentType: "application/json; charset=utf-8",
                .contentLength: "\(data.count)",
            ],
            body: .init(byteBuffer: ByteBuffer(data: data))
        )
    }
}

#if hasFeature(RetroactiveAttribute)
extension GraphQLResult: @retroactive ResponseGenerator {}
#else
extension GraphQLResult: ResponseGenerator {}
#endif
