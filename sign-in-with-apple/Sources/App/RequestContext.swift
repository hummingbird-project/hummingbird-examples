import Foundation
import Hummingbird
import HummingbirdAuth
import Logging

struct AppRequestContext: SessionRequestContext, RequestContext {
    /// core context
    public var coreContext: CoreRequestContextStorage
    /// Session
    public let sessions: SessionContext<Session>

    ///  Initialize an `RequestContext`
    /// - Parameters:
    ///   - applicationContext: Context from Application that instigated the request
    ///   - channel: Channel that generated this request
    ///   - logger: Logger
    public init(source: Source) {
        self.coreContext = .init(source: source)
        self.sessions = .init()
    }

    var requestDecoder: SIWARequestDecoder {
        SIWARequestDecoder()
    }
}

/// Sign in with Apple uses URLEncoded forms, so we need a request decoder that will read URL Encoded forms
struct SIWARequestDecoder: RequestDecoder {
    func decode<T>(_ type: T.Type, from request: Request, context: some RequestContext) async throws -> T where T: Decodable {
        /// if no content-type header exists or it is an unknown content-type return bad request
        guard let header = request.headers[.contentType] else { throw HTTPError(.badRequest) }
        guard let mediaType = MediaType(from: header) else { throw HTTPError(.badRequest) }
        switch mediaType {
        case .applicationJson:
            return try await JSONDecoder().decode(type, from: request, context: context)
        case .applicationUrlEncoded:
            return try await URLEncodedFormDecoder().decode(type, from: request, context: context)
        default:
            throw HTTPError(.badRequest)
        }
    }
}
