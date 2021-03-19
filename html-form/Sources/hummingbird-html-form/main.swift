import ArgumentParser

struct HummingbirdArguments: ParsableCommand {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 8080

    func run() {
        do {
            try runApp(self)
        } catch {
            print("\(error)")
        }
    }
}

HummingbirdArguments.main()
