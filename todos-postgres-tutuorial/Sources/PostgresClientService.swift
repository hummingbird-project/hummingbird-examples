import Hummingbird
@_spi(ConnectionPool) import PostgresNIO
import ServiceLifecycle

/// Manage the lifecycle of a PostgresClient
struct PostgresClientService: Service {
    let client: PostgresClient

    func run() async {
        await cancelOnGracefulShutdown {
            await self.client.run()
        }
    }
}
