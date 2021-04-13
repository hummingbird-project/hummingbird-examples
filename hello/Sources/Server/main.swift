import App
import ArgumentParser
import Hummingbird

struct HummingbirdArguments: ParsableCommand {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 8080

    func run() {
        let app = HBApplication(
            configuration: .init(
                address: .hostname(self.hostname, port: self.port),
                serverName: "Hummingbird"
            )
        )
        app.configure()
        app.start()
        app.wait()
    }
}

HummingbirdArguments.main()
