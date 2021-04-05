import ArgumentParser
import hummingbird_testing

struct ApplicationArguments: ParsableCommand {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"
    
    @Option(name: .shortAndLong)
    var port: Int = 8080
    
    public func run() throws {
        try Boot.runApp(hostname: hostname, port: port)
    }
}

ApplicationArguments.main()
