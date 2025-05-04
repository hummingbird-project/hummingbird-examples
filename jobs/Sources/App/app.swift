import ArgumentParser
import Hummingbird
import Logging

@main
struct HummingbirdArguments: AsyncParsableCommand, AppArguments {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 8080

    @Option(name: .shortAndLong)
    var logLevel: Logger.Level?

    @Flag(name: .long)
    var processJobs: Bool = false

    @Flag(name: .long)
    var useMemory: Bool = false

    func run() async throws {
        let serviceGroup = try await buildServiceGroup(self)
        try await serviceGroup.run()
    }
}

/// Extend `Logger.Level` so it can be used as an argument
#if hasFeature(RetroactiveAttribute)
extension Logger.Level: @retroactive ExpressibleByArgument {}
#else
extension Logger.Level: ExpressibleByArgument {}
#endif
