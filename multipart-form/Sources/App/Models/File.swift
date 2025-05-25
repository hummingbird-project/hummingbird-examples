import Hummingbird
import MultipartKit
import StructuredFieldValues

public struct File: MultipartPartConvertible, Decodable {
    public let data: ByteBuffer
    public let filename: String
    public let contentType: String

    public var multipart: MultipartPart? { nil }

    public init?(multipart: MultipartPart) {
        self.data = multipart.body
        guard let contentType = multipart.headers["content-type"].first else { return nil }
        guard let contentDispositionHeader = multipart.headers["content-disposition"].first else { return nil }
        guard let contentDisposition = try? StructuredFieldValueDecoder().decode(MultipartContentDispostion.self, from: contentDispositionHeader)
        else { return nil }
        guard let filename = contentDisposition.parameters.filename else { return nil }
        self.filename = filename
        self.contentType = contentType
    }

    public init(
        data: ByteBuffer,
        filename: String,
        contentType: String
    ) {
        self.data = data
        self.filename = filename
        self.contentType = contentType
    }
}

extension File {
    var urlSafeFilename: String {
        var urlSafeFileName = filename.replacingOccurrences(of: " ", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        urlSafeFileName = urlSafeFileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? urlSafeFileName
        return urlSafeFileName
    }
}

struct MultipartContentDispostion: StructuredFieldValue {
    struct Parameters: StructuredFieldValue {
        static let structuredFieldType: StructuredFieldType = .dictionary
        var name: String
        var filename: String?
    }
    static let structuredFieldType: StructuredFieldType = .item
    var item: String
    var parameters: Parameters
}

extension StructuredFieldValueDecoder {
    public func decode<StructuredField: StructuredFieldValue>(
        _ type: StructuredField.Type = StructuredField.self,
        from string: String
    ) throws -> StructuredField {
        let decoded = try string.utf8.withContiguousStorageIfAvailable { bytes in
            try self.decode(type, from: bytes)
        }
        if let decoded {
            return decoded
        }
        var string = string
        string.makeContiguousUTF8()
        return try self.decode(type, from: string)
    }
}
