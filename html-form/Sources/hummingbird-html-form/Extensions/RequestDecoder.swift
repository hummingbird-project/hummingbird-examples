import Hummingbird
import HummingbirdURLEncoded


struct RequestDecoder: HBRequestDecoder {
    let decoder = URLEncodedFormDecoder()

    func decode<T>(_ type: T.Type, from request: HBRequest) throws -> T where T : Decodable {
        if request.headers["content-type"].first == "application/x-www-form-urlencoded" {
            return try decoder.decode(type, from: request)
        }
        throw HBHTTPError(.unsupportedMediaType)
    }
}
