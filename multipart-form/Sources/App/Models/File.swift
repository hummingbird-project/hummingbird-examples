import Hummingbird
import MultipartKit
import StructuredFieldValues

struct File: MultipartPartConvertible, Decodable {
    let data: ByteBuffer
    let filename: String
    let contentType: String

    var multipart: MultipartPart? { nil }

    init?(multipart: MultipartPart) {
        self.data = multipart.body
        guard let contentType = multipart.headers["content-type"].first else { return nil }
        guard let contentDispositionHeader = multipart.headers["content-disposition"].first else { return nil }
        guard let contentDisposition = try? StructuredFieldValueDecoder().decode(MultipartContentDispostion.self, from: contentDispositionHeader)
        else { return nil }
        guard let filename = contentDisposition.parameters.filename else { return nil }
        self.filename = filename
        self.contentType = contentType
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
