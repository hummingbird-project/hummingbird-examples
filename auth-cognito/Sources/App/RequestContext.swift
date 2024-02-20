import Hummingbird
import HummingbirdAuth
import HummingbirdRouter
import Logging
import NIOCore
import SotoCognitoAuthenticationKit

/// Request context
struct AuthCognitoRequestContext: HBAuthRequestContext, HBRemoteAddressRequestContext, HBRouterRequestContext {
    var coreContext: HBCoreRequestContext
    /// required by authentication framework
    var auth: HBLoginCache
    /// required by result builder router
    var routerContext: HBRouterBuilderContext
    let channel: Channel?
    /// Connected host address
    var remoteAddress: SocketAddress? {
        guard let channel else { return nil }
        return channel.remoteAddress
    }

    /// initializer required by live server
    init(channel: Channel, logger: Logger) {
        self.coreContext = .init(allocator: channel.allocator, logger: logger)
        self.auth = .init()
        self.routerContext = .init()
        self.channel = channel
    }
}

/// Wrapper for cognito context data
struct HBCognitoContextData: CognitoContextData {
    let request: HBRequest
    let context: AuthCognitoRequestContext

    public var contextData: CognitoIdentityProvider.ContextDataType? {
        let host = self.request.head.authority ?? "localhost"
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
            httpHeaders: self.request.headers.map { CognitoIdentityProvider.HttpHeader(headerName: $0.name.rawName, headerValue: $0.value) },
            ipAddress: ipAddress,
            serverName: host,
            serverPath: self.request.uri.path
        )
    }
}
