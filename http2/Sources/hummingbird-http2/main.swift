import ArgumentParser

struct AppArguments: ParsableCommand {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 8080

    @Option(name: .shortAndLong, help: "PEM file containing certificate chain")
    var certificateChain: String

    @Option(name: .long, help: "PEM file containing private key")
    var privateKey: String

    func run() throws {
        try App(arguments: self).run()
    }
}

AppArguments.main()
