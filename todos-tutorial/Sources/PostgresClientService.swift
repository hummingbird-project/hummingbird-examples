import Hummingbird
@_spi(ConnectionPool) import PostgresNIO
import ServiceLifecycle

/// Manage the lifecycle of a PostgresClient
actor PostgresClientService: Service {
    let client: PostgresClient

    init(client: PostgresClient) {
        self.client = client
    }

    func run() async throws {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.client.run()
            }
            // wait until graceful shutdown and then cancel all tasks
            await GracefulShutdownWaiter().wait()
            group.cancelAll()
            print("Shutdown postgres")
        }
    }
}
