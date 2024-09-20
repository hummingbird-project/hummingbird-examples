import Hummingbird

/// Caching file provider
/// 
/// Takes the results from a base file provider and caches them in memory so
/// the server only needs to make one call to the file provider for any particular
/// file
struct CachingFileProvider<BaseProvider: FileProvider>: FileProvider where BaseProvider.FileIdentifier: Sendable & Hashable, BaseProvider.FileAttributes: Sendable {
    typealias FileAttributes = BaseProvider.FileAttributes
    typealias FileIdentifier = BaseProvider.FileIdentifier

    let base: BaseProvider
    let cache: Cache

    init(_ base: BaseProvider) {
        self.base = base
        self.cache = .init()
    }

    func getFileIdentifier(_ path: String) -> FileIdentifier? {
        base.getFileIdentifier(path)
    }

    func getAttributes(id: FileIdentifier) async throws -> FileAttributes? {
        // do we have the attributes for this file in memory already
        if let attributes = await cache.getAttributes(id: id) {
            return attributes
        }
        if let attributes = try await base.getAttributes(id: id) {
            await cache.setAttributes(id: id, attributes: attributes)
            return attributes
        }
        return nil
    }

    func loadFile(id: FileIdentifier, context: some RequestContext) async throws -> ResponseBody {
        // do we have the buffer for this file in memory already
        if let buffer = await cache.getBuffer(id: id) {
            return .init(byteBuffer: buffer)
        }
        let body = try await base.loadFile(id: id, context: context)
        // return ResponseBody that will collate the response body and store it in the cache
        return ResponseBody(contentLength: nil) { writer in
            let collatingBodyWriter = CollatingBodyWriter(parent: writer) { buffer in
                await self.cache.setBuffer(id: id, buffer: buffer)
            }
            try await body.write(collatingBodyWriter)
        }
    }

    func loadFile(id: FileIdentifier, range: ClosedRange<Int>, context: some RequestContext) async throws -> ResponseBody {
        // do we have the buffer for this file in memory already
        if let buffer = await cache.getBuffer(id: id), 
            let slice = buffer.getSlice(at: range.lowerBound, length: range.count) {
            return .init(byteBuffer: slice)
        }
        return try await base.loadFile(id: id, range: range, context: context)
    }

    /// File cache
    actor Cache {
        var contents: [FileIdentifier: (attributes: FileAttributes, buffer: ByteBuffer?)] = [:]

        func getAttributes(id: FileIdentifier) -> FileAttributes? {
            contents[id]?.attributes
        }

        func getBuffer(id: FileIdentifier) -> ByteBuffer? {
            contents[id]?.buffer
        }

        func setAttributes(id: FileIdentifier, attributes: FileAttributes) {
            contents[id] = (attributes: attributes, buffer: nil)
        }

        func setBuffer(id: FileIdentifier, buffer: ByteBuffer) {
            contents[id]?.buffer = buffer 
        }
    }
}

/// As the response is written it is collated into one big buffer and on finish
/// a closure is called with this collated buffer
struct CollatingBodyWriter: ResponseBodyWriter {
    var parent: any ResponseBodyWriter
    let onFinish: @Sendable (ByteBuffer) async -> ()
    var completeBuffer: ByteBuffer = .init()

    mutating func write(_ buffer: ByteBuffer) async throws {
        var bufferCopy = buffer
        self.completeBuffer.writeBuffer(&bufferCopy)
        try await parent.write(buffer)
    }

    func finish(_ trailingHeaders: HTTPFields?) async throws {
        await self.onFinish(completeBuffer)
        try await parent.finish(nil)
    }
}
