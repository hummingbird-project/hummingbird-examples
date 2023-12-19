import ArgumentParser
import Hummingbird

@main
struct HummingbirdArguments: ParsableCommand, AppArguments {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 8080

    @Option(name: .shortAndLong, help: "PEM file containing certificate chain")
    var certificateChain: String

    @Option(name: .long, help: "PEM file containing private key")
    var privateKey: String

    func run() throws {
        let app = HBApplication(
            configuration: .init(
                address: .hostname(self.hostname, port: self.port),
                serverName: "Hummingbird",
                idleTimeoutConfiguration: .init(readTimeout: .seconds(5), writeTimeout: .seconds(5))
            )
        )
        try app.configure(self)
        try app.start()
        app.wait()
    }
}
