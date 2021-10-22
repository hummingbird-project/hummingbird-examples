import App
import ArgumentParser
import Hummingbird

struct HummingbirdArguments: ParsableCommand, AppArguments {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 8080

    @Flag(name: .long)
    var processJobs: Bool = false

    func run() throws {
        let app = HBApplication(
            configuration: .init(
                address: .hostname(self.hostname, port: self.port),
                serverName: "Hummingbird",
                noHTTPServer: self.processJobs
            )
        )
        try app.configure(self)
        try app.start()
        app.wait()
    }
}

HummingbirdArguments.main()
