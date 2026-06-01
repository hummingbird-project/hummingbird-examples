import Foundation
import Hummingbird

/// Request body decoder that handles JSON and URL-encoded forms.
/// Falls back to JSON when no Content-Type header is present (keeps API tests working).
struct AppRequestDecoder: RequestDecoder {
    func decode<T>(_ type: T.Type, from request: Request, context: some RequestContext) async throws -> T where T: Decodable {
        guard let header = request.headers[.contentType] else {
            return try await JSONDecoder().decode(type, from: request, context: context)
        }
        guard let mediaType = MediaType(from: header) else {
            return try await JSONDecoder().decode(type, from: request, context: context)
        }
        switch mediaType {
        case .applicationUrlEncoded:
            return try await URLEncodedFormDecoder().decode(type, from: request, context: context)
        default:
            return try await JSONDecoder().decode(type, from: request, context: context)
        }
    }
}
