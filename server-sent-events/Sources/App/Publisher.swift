import Foundation
import ServiceLifecycle

/// Basic PUB/SUB service.
actor Publisher<Value: Sendable>: Service {
    typealias SubscriptionID = UUID
    enum SubscriptionCommand {
        case add(SubscriptionID, AsyncStream<Value>.Continuation)
        case remove(SubscriptionID)
    }

    nonisolated let (subStream, subSource) = AsyncStream<SubscriptionCommand>.makeStream()

    init() {
        self.subscriptions = [:]
    }

    /// Publish to service
    /// - Parameter value: Value being published
    func publish(_ value: Value) async {
        for subscription in self.subscriptions.values {
            subscription.yield(value)
        }
    }

    ///  Subscribe to service
    /// - Returns: AsyncStream of values, and subscription identifier
    nonisolated func subscribe() -> (AsyncStream<Value>, SubscriptionID) {
        let id = SubscriptionID()

        // Each subscription gets an AsyncStream and a SubscriptionID
        // The AsyncStream is unbounded by default. This means that no messages are lost, but
        // any backpressure applied to the AsyncStream will cause the stream to buffer messages
        // in memory. If the client is unable to keep up with the rate of data production, the
        // data will stack up in the server's memory.
        let (stream, source) = AsyncStream<Value>.makeStream()
        subSource.yield(.add(id, source))
        return (stream, id)
    }

    ///  Unsubscribe from service
    /// - Parameter id: Subscription identifier
    nonisolated func unsubscribe(_ id: SubscriptionID) {
        subSource.yield(.remove(id))
    }

    /// Service run function
    func run() async throws {
        try await withGracefulShutdownHandler {
            for try await command in self.subStream {
                switch command {
                case .add(let id, let source):
                    self._addSubsciber(id, source: source)
                case .remove(let id):
                    self._removeSubsciber(id)
                }
            }
        } onGracefulShutdown: {
            self.subSource.finish()
        }
    }

    private func _addSubsciber(_ id: SubscriptionID, source: AsyncStream<Value>.Continuation) {
        self.subscriptions[id] = source
    }

    private func _removeSubsciber(_ id: SubscriptionID) {
        self.subscriptions[id]?.finish()
        self.subscriptions[id] = nil
    }

    var subscriptions: [SubscriptionID: AsyncStream<Value>.Continuation]
}
