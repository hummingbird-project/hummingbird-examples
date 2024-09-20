import Foundation
import Hummingbird
import SotoS3

struct S3FileProvider: FileProvider {
    let bucket: String
    let rootFolder: String
    let s3: S3

    /// File attributes required by ``FileMiddleware``
    struct FileAttributes: FileMiddlewareFileAttributes {
        /// Is file a folder
        var isFolder: Bool { false }
        /// Size of file
        let size: Int
        /// Last time file was modified
        let modificationDate: Date

        /// Initialize FileAttributes
        init(size: Int, modificationDate: Date) {
            self.size = size
            self.modificationDate = modificationDate
        }
    }

    typealias FileIdentifier = String

    func getFileIdentifier(_ path: String) -> String? {
        if path.first == "/" {
            return "\(self.rootFolder)\(path.dropFirst())"
        } else {
            return "\(self.rootFolder)\(path)"
        }
    }

    func getAttributes(id: String) async throws -> FileAttributes? {
        do {
            let head = try await self.s3.headObject(.init(bucket: self.bucket, key: id))
            guard let size = head.contentLength, let modificationDate = head.lastModified else { return nil }
            return .init(size: numericCast(size), modificationDate: modificationDate)
        } catch {
            return nil
        }
    }

    func loadFile(id: String, context: some RequestContext) async throws -> ResponseBody {
        let response = try await self.s3.getObject(.init(bucket: self.bucket, key: id), logger: context.logger)
        return ResponseBody(asyncSequence: response.body)
    }

    func loadFile(id: String, range: ClosedRange<Int>, context: some RequestContext) async throws -> ResponseBody {
        let response = try await self.s3.getObject(
            .init(bucket: self.bucket, key: id, range: "bytes \(range.lowerBound)-\(range.upperBound)/*"), 
            logger: context.logger
        )
        return ResponseBody(asyncSequence: response.body)
    }
}