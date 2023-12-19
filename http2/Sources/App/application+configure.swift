import Hummingbird
import HummingbirdHTTP2

public protocol AppArguments {
    var tlsConfiguration: TLSConfiguration { get throws }
}

extension HBApplication {
    /// configure your application
    /// add middleware
    /// setup the encoder/decoder
    /// add your routes
    public func configure(_ arguments: AppArguments) throws {
        // Add HTTP2 TLS Upgrade option
        try server.addHTTP2Upgrade(
            tlsConfiguration: arguments.tlsConfiguration,
            idleReadTimeout: .seconds(30)
        )

        router.get("/http") { request in
            return "Using http v\(request.version.major).\(request.version.minor)"
        }
    }
}
