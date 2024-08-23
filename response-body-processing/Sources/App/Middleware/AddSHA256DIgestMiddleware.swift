import Crypto
import HTTPTypes
import Hummingbird

extension HTTPField.Name {
    /// Extend HTTPField to create new header type `.digest`
    static var digest: Self { .init("Digest")! }
}

/// ResponseBodyWriter that updates a SHA256 digest with the contents of a response body and
/// once it is finished add the digest as a header in the trailer headers
class CalculateSHA256DigestResponseBodyWriter<ParentWriter: ResponseBodyWriter>: ResponseBodyWriter {
    let parentWriter: ParentWriter
    var sha256: SHA256

    init(parentWriter: ParentWriter) {
        self.parentWriter = parentWriter
        self.sha256 = SHA256()
    }

    func write(_ buffer: ByteBuffer) async throws {
        buffer.withUnsafeReadableBytes { bytes in
            self.sha256.update(bufferPointer: bytes)
        }
        try await self.parentWriter.write(buffer)
    }

    func finish(_ trailingHeaders: HTTPFields?) async throws {
        // we've finished the response body, so lets calculate the final SHA256
        // and add it as a trailing header
        let digest = self.sha256.finalize()
        var trailingHeaders = trailingHeaders ?? [:]
        trailingHeaders[.digest] = "sha256=\(digest.hexDigest())"
        try await self.parentWriter.finish(trailingHeaders)
    }
}

extension ResponseBodyWriter {
    var addingSHA256Digest: some ResponseBodyWriter { CalculateSHA256DigestResponseBodyWriter(parentWriter: self) }
}

/// Middleware that edits a response to write buffers to the CalculateSHA256DigestResponseBodyWriter instead of
/// the writer provided
struct AddSHA256DigestMiddleware<Context: RequestContext>: RouterMiddleware {
    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        let response = try await next(request, context)
        if response.headers[.contentLength] != nil { return response }
        // can only add trailer headers to responses that are chunked
        var editedResponse = response
        editedResponse.body = .init { writer in
            try await response.body.write(writer.addingSHA256Digest)
        }
        return editedResponse
    }
}

public extension Sequence<UInt8> {
    /// return a hexEncoded string buffer from an array of bytes
    func hexDigest() -> String {
        return self.map { String(format: "%02x", $0) }.joined(separator: "")
    }
}
