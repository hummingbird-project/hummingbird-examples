import Hummingbird
import HummingbirdHTTP2

struct App {
    let arguments: AppArguments

    func run() throws {
        let app = HBApplication(configuration: .init(address: .hostname(arguments.hostname, port: arguments.port)))
        // Add HTTP2 TLS Upgrade option
        try app.addHTTP2Upgrade(tlsConfiguration: getTLSConfig())
        
        app.router.get("/http") { request in
            return "Using http v\(request.version.major).\(request.version.minor)"
        }
        app.start()
        app.wait()
    }

    func getTLSConfig() throws -> TLSConfiguration{
        let certificateChain = try NIOSSLCertificate.fromPEMFile(arguments.certificateChain)
        let privateKey = try NIOSSLPrivateKey.init(file: arguments.privateKey, format: .pem)
        return TLSConfiguration.forServer(certificateChain: certificateChain.map {.certificate($0)}, privateKey: .privateKey(privateKey))
    }
}
