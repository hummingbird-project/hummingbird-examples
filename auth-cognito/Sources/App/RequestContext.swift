import Hummingbird
import HummingbirdAuth
import Logging
import NIOCore
import SotoCognitoAuthenticationKit

struct AuthCognitoRequestContext: HBAuthRequestContextProtocol, HBRemoteAddressRequestContext {
    var coreContext: HBCoreRequestContext
    var auth: HBLoginCache
    let channel: Channel?
    /// Connected host address
    var remoteAddress: SocketAddress? {
        guard let channel else { return nil }
        return channel.remoteAddress
    }

    init(allocator: ByteBufferAllocator, logger: Logger) {
        self.coreContext = .init(allocator: allocator, logger: logger)
        self.auth = .init()
        self.channel = nil
    }

    init(channel: Channel, logger: Logger) {
        self.coreContext = .init(allocator: channel.allocator, logger: logger)
        self.auth = .init()
        self.channel = channel
    }
}

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
