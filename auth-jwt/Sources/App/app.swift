import ArgumentParser
import Dispatch
import Hummingbird

@main
struct HummingbirdArguments: AsyncParsableCommand, AppArguments {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 8080

    @Flag(name: .shortAndLong)
    var migrate: Bool = false

    @Flag(name: .shortAndLong)
    var inMemoryDatabase: Bool = false

    func run() async throws {
        let app = HBApplication(
            configuration: .init(
                address: .hostname(self.hostname, port: self.port),
                serverName: "Hummingbird"
            )
        )
        try await app.configure(arguments: self)
        try await app.asyncRun()
    }
}
