import Hummingbird
import MultipartKit
import StructuredFieldValues

/// A structure representing a file in a multipart request.
public struct File: MultipartPartConvertible, Decodable {
    /// The raw data of the file.
    public let data: ByteBuffer

    /// The name of the file.
    public let filename: String

    /// The MIME type of the file.
    public let contentType: String

    /// A computed property that returns `nil` if this structure does not provide a multipart representation.
    public var multipart: MultipartPart? { nil }

    /// Initializes a `File` instance from a `MultipartPart`.
    ///
    /// - Parameter multipart: The multipart part containing file data.
    /// - Returns: A `File` instance if initialization is successful; otherwise, `nil`.
    public init?(multipart: MultipartPart) {
        self.data = multipart.body
        guard let contentType = multipart.headers["content-type"].first else {
            return nil
        }
        guard let contentDispositionHeader = multipart.headers["content-disposition"].first else {
            return nil
        }
        guard let contentDisposition = try? StructuredFieldValueDecoder().decode(
            MultipartContentDispostion.self,
            from: contentDispositionHeader
        ) else {
            return nil
        }
        guard let filename = contentDisposition.parameters.filename else {
            return nil
        }
        self.filename = filename
        self.contentType = contentType
    }

    /// Initializes a `File` instance with the specified data, filename, and content type.
    ///
    /// - Parameters:
    ///   - data: The raw data of the file.
    ///   - filename: The name of the file.
    ///   - contentType: The MIME type of the file.
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
    /// A computed property that returns a URL-safe version of the filename.
    var urlSafeFilename: String {
        // Replace spaces with hyphens and trim whitespace
        var urlSafeFileName = filename.replacingOccurrences(of: " ", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)

        // Encode the filename for use in a URL path
        urlSafeFileName = urlSafeFileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? urlSafeFileName
        return urlSafeFileName
    }
}

/// A structure representing the content disposition of a multipart part.
struct MultipartContentDispostion: StructuredFieldValue {
    /// A structure representing the parameters of the content disposition.
    struct Parameters: StructuredFieldValue {
        static let structuredFieldType: StructuredFieldType = .dictionary

        /// The name of the form field.
        var name: String

        /// The filename, if provided.
        var filename: String?
    }

    static let structuredFieldType: StructuredFieldType = .item

    /// The item representing the content disposition.
    var item: String

    /// The parameters associated with the content disposition.
    var parameters: Parameters
}

extension StructuredFieldValueDecoder {
    /// Decodes a structured field value from a string.
    ///
    /// - Parameters:
    ///   - type: The type of the structured field value to decode.
    ///   - string: The string representation of the structured field value.
    /// - Throws: An error if decoding fails.
    /// - Returns: The decoded structured field value.
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
