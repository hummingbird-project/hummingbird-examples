import ArgumentParser
import Hummingbird

@main
struct HummingbirdArguments: AsyncParsableCommand, AppArguments {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 8081

    @Option(name: .shortAndLong)
    var location: String = ""

    @Option(name: .shortAndLong)
    var target: String = "http://localhost:8080"

    func run() async throws {
        let app = buildApplication(self)
        try await app.runService()
    }
}
