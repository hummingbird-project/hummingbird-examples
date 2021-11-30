import App
import ArgumentParser
import Hummingbird

struct ProxyServer: ParsableCommand, AppArguments {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 8081

    @Option(name: .shortAndLong)
    var target: String = "http://localhost:8080"

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

ProxyServer.main()
