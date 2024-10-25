import GraphQL
import HTTPTypes
import Hummingbird

extension GraphQLError {
    /// Simple test to determine if GraphQLError is something that the client can address.
    private var isRequestError: Bool {
        message.starts(with: "Syntax Error") ? true : false
    }

    /// If the client sends a request that causes GraphQL to crash, it should report back 400 Bad Request.
    /// But SwiftGraphQL will throw causing a 500 Internal Server Error for syntax errors that can be resolved by the client.
    public var status: HTTPResponse.Status {
        self.isRequestError ? .badRequest : .internalServerError
    }

    public var headers: HTTPFields {
        [.contentType: "application/json"]
    }

    public func response(from request: Request, context: some RequestContext) -> Response {
        .init(status: self.status, headers: self.headers, body: .init(byteBuffer: ByteBuffer(string: message)))
    }
}

#if hasFeature(RetroactiveAttribute)
extension GraphQLError: @retroactive HTTPResponseError {}
#else
extension GraphQLError: HTTPResponseError {}
#endif
