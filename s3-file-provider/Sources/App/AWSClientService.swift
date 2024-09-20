import ServiceLifecycle
import SotoCore

/// Service that manages the lifecycle of an AWSClient
struct AWSClientService: Service {
    let client: AWSClient

    func run() async throws {
        // Ignore cancellation error
        try? await gracefulShutdown()
        try await self.client.shutdown()
    }
}

