import ArgumentParser
import Hummingbird

@main
struct HummingbirdArguments: AsyncParsableCommand, AppArguments {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 8080

    @Option(name: .shortAndLong)
    var driver: JobQueueDriverEnum = .redis

    @Flag(name: .long)
    var processJobs: Bool = false

    @Flag(name: .long)
    var useMemory: Bool = false

    func run() async throws {
        let serviceGroup = try await buildServiceGroup(self)
        try await serviceGroup.run()
    }
}

extension JobQueueDriverEnum: ExpressibleByArgument {}
