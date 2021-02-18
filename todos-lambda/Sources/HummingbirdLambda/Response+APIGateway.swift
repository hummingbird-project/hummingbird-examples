import AWSLambdaEvents
import AWSLambdaRuntime
import ExtrasBase64
import Hummingbird
import NIOHTTP1

protocol APIResponse {
    init(
        statusCode: AWSLambdaEvents.HTTPResponseStatus,
        headers: AWSLambdaEvents.HTTPHeaders?,
        multiValueHeaders: HTTPMultiValueHeaders?,
        body: String?,
        isBase64Encoded: Bool?
    )
}

extension HBResponse {
    func apiResponse<Response: APIResponse>() -> Response {
        let groupedHeaders: [String: [String]] = self.headers.reduce([:]) { result, item in
            var result = result
            if result[item.name] == nil {
                result[item.name] = [item.value]
            } else {
                result[item.name]?.append(item.value)
            }
            return result
        }
        let singleHeaders = groupedHeaders.compactMapValues { item -> String? in
            if item.count == 1 {
                return item.first!
            } else {
                return nil
            }
        }
        let multiHeaders = groupedHeaders.compactMapValues { item -> [String]? in
            if item.count > 1 {
                return item
            } else {
                return nil
            }
        }
        var body: String? = nil
        var isBase64Encoded: Bool? = nil
        if case .byteBuffer(let buffer) = self.body {
            if let contentType = self.headers["content-type"].first {
                let type = contentType[..<(contentType.firstIndex(of: ";") ?? contentType.endIndex)]
                switch type {
                case "text/plain", "application/json", "application/x-www-form-urlencoded":
                    body = String(buffer: buffer)
                default:
                    break
                }
            }
            if body == nil {
                body = String(base64Encoding: buffer.readableBytesView)
                isBase64Encoded = true
            }
        }
        return .init(
            statusCode: .init(code: self.status.code),
            headers: singleHeaders,
            multiValueHeaders: multiHeaders,
            body: body,
            isBase64Encoded: isBase64Encoded
        )
    }
}
