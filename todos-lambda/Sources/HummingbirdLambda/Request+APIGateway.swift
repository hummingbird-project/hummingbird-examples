import AWSLambdaEvents
import AWSLambdaRuntime
import ExtrasBase64
import Hummingbird
import NIOHTTP1

protocol APIRequest {
    var path: String { get }
    var httpMethod: AWSLambdaEvents.HTTPMethod { get }
    var queryStringParameters: [String: String]? { get }
    var multiValueQueryStringParameters: [String: [String]]? { get }
    var headers: AWSLambdaEvents.HTTPHeaders { get }
    var multiValueHeaders: HTTPMultiValueHeaders { get }
    var body: String? { get }
    var isBase64Encoded: Bool { get }
}

extension HBRequest {
    /// Specialization of HBLambda.request where `In` is `APIGateway.Request`
    convenience init(context: Lambda.Context, application: HBApplication, from: APIRequest) throws {
        // construct URI with query parameters
        var uri = from.path
        var queryParams: [String] = []
        var queryStringParameters = from.queryStringParameters ?? [:]
        // go through list of multi value query string params first, removing any
        // from the single value list if they are found in the multi value list
        from.multiValueQueryStringParameters?.forEach { multiValueQuery in
            queryStringParameters[multiValueQuery.key] = nil
            queryParams += multiValueQuery.value.map { "\(multiValueQuery.key)=\($0)" }
        }
        queryParams += queryStringParameters.map { "\($0.key)=\($0.value)"}
        if queryParams.count > 0 {
            uri += "?\(queryParams.joined(separator: "&"))"
        }

        // construct headers
        var headers = NIOHTTP1.HTTPHeaders(from.headers.map { ($0.key, $0.value) })
        from.multiValueHeaders.forEach { multiValueHeader in
            headers.remove(name: multiValueHeader.key)
            for header in multiValueHeader.value {
                headers.add(name: multiValueHeader.key, value: header)
            }
        }
        let head = HTTPRequestHead(
            version: .init(major: 2, minor: 0),
            method: .init(rawValue: from.httpMethod.rawValue),
            uri: uri,
            headers: headers
        )
        // get body
        let body: ByteBuffer?
        if let apiGatewayBody = from.body {
            if from.isBase64Encoded {
                let base64Decoded = try apiGatewayBody.base64decoded()
                body = context.allocator.buffer(bytes: base64Decoded)
            } else {
                body = context.allocator.buffer(string: apiGatewayBody)
            }
        } else {
            body = nil
        }

        self.init(
            head: head,
            body: .byteBuffer(body),
            application: application,
            eventLoop: context.eventLoop,
            allocator: context.allocator
        )
    }
}
