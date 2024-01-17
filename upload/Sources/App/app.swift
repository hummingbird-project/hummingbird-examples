import ArgumentParser
import Hummingbird

@main
struct HummingbirdArguments: AsyncParsableCommand, AppArguments {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 8080

    func run() async throws {
        let app = buildApplication(args: self)
        try await app.runService()
    }
}

protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
}
