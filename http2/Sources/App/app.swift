import ArgumentParser
import Hummingbird
import NIOSSL

@main
struct HummingbirdArguments: AsyncParsableCommand, AppArguments {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 8081

    @Option(name: .shortAndLong, help: "PEM file containing certificate chain")
    var certificateChain: String = "resources/certs/server.crt"

    @Option(name: .long, help: "PEM file containing private key")
    var privateKey: String = "resources/certs/server.key"

    var tlsConfiguration: TLSConfiguration {
        get throws {
            let certificateChain = try NIOSSLCertificate.fromPEMFile(self.certificateChain)
            let privateKey = try NIOSSLPrivateKey(file: self.privateKey, format: .pem)
            return TLSConfiguration.makeServerConfiguration(
                certificateChain: certificateChain.map { .certificate($0) },
                privateKey: .privateKey(privateKey)
            )
        }
    }

    func run() async throws {
        let app = try buildApplication(
            arguments: self,
            configuration: .init(
                address: .hostname(self.hostname, port: self.port),
                serverName: "Hummingbird"
            )
        )
        try await app.runService()
    }
}
