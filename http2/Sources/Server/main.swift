import App
import ArgumentParser
import Hummingbird

struct HummingbirdArguments: ParsableCommand, AppArguments {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 8080

    @Option(name: .long, help: "PEM file containing trust root")
    var caCert: String

    @Option(name: .shortAndLong, help: "PEM file containing certificate chain")
    var certificateChain: String

    @Option(name: .long, help: "PEM file containing private key")
    var privateKey: String

    func run() throws {
        let app = HBApplication(
            configuration: .init(
                address: .hostname(self.hostname, port: self.port),
                serverName: "Hummingbird"
            )
        )
        try app.configure(self)
        try app.start()
        app.wait()
    }
}

HummingbirdArguments.main()
