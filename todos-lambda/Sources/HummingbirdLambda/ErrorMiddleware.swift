import Hummingbird

/// Catch HBHTTPErrors and return as valid response
struct LambdaErrorMiddleware: HBMiddleware {
    func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        return next.respond(to: request).flatMapErrorThrowing { error in
            if let error = error as? HBHTTPError {
                return error.response(allocator: request.allocator)
            }
            throw error
        }
    }
}

extension HBHTTPError {
    /// Generate response from error
    /// - Parameter allocator: Byte buffer allocator used to allocate message body
    /// - Returns: Response
    public func response(allocator: ByteBufferAllocator) -> HBResponse {
        var headers: HTTPHeaders = self.headers

        let body: HBResponseBody
        if let message = self.body {
            let buffer = allocator.buffer(string: message)
            body = .byteBuffer(buffer)
            headers.replaceOrAdd(name: "content-length", value: buffer.readableBytes.description)
        } else {
            body = .empty
        }
        return .init(status: status, headers: headers, body: body)
    }

}
