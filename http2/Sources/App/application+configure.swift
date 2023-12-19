import Hummingbird
import HummingbirdHTTP2

public protocol AppArguments {
    var certificateChain: String { get }
    var privateKey: String { get }
}

extension HBApplication {
    /// configure your application
    /// add middleware
    /// setup the encoder/decoder
    /// add your routes
    public func configure(_ arguments: AppArguments) throws {
        // Add HTTP2 TLS Upgrade option
        try server.addHTTP2Upgrade(
            tlsConfiguration: self.getTLSConfig(arguments), 
            idleReadTimeout: .seconds(30)
        )

        router.get("/http") { request in
            return "Using http v\(request.version.major).\(request.version.minor)"
        }
    }

    func getTLSConfig(_ arguments: AppArguments) throws -> TLSConfiguration {
        let certificateChain = try NIOSSLCertificate.fromPEMFile(arguments.certificateChain)
        let privateKey = try NIOSSLPrivateKey(file: arguments.privateKey, format: .pem)
        return TLSConfiguration.makeServerConfiguration(
            certificateChain: certificateChain.map { .certificate($0) },
            privateKey: .privateKey(privateKey)
        )
    }
}
