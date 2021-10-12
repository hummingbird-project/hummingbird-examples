import Hummingbird
import SotoCognitoAuthenticationKit

extension HBRequest {
    var aws: HBApplication.AWS { return self.application.aws }
    var cognito: HBApplication.Cognito { return self.application.cognito }
}

extension HBRequest: CognitoContextData {
    public var contextData: CognitoIdentityProvider.ContextDataType? {
        let host = headers["Host"].first ?? "localhost"
        guard let remoteAddress = self.context.remoteAddress else { return nil }
        let ipAddress: String
        switch remoteAddress {
        case .v4(let address):
            ipAddress = address.host
        case .v6(let address):
            ipAddress = address.host
        default:
            return nil
        }
        return .init(
            httpHeaders: self.headers.map { CognitoIdentityProvider.HttpHeader(headerName: $0.name, headerValue: $0.value) },
            ipAddress: ipAddress,
            serverName: host,
            serverPath: self.uri.path
        )
    }
}
