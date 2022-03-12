import ArgumentParser
import Dispatch
import Hummingbird

@main
struct TodosPostgresArguments: ParsableCommand, AppArguments {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 8080

    func run() throws {
        let dg = DispatchGroup()
        dg.enter()
        Task {
            do {
                try await self.run()
            } catch {
                print(error)
            }
            dg.leave()
        }
        dg.wait()
    }

    func run() async throws {
        let app = HBApplication(
            configuration: .init(
                address: .hostname(self.hostname, port: self.port),
                serverName: "TodosPostgres"
            )
        )
        try await app.configure(self)
        try app.start()
        app.wait()
    }
}
