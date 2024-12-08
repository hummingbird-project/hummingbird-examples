import Foundation
import ServiceLifecycle

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

    func publish(_ value: Value) async {
        for subscription in self.subscriptions.values {
            subscription.yield(value)
        }
    }

    nonisolated func addSubsciber() -> (AsyncStream<Value>, SubscriptionID) {
        let id = SubscriptionID()
        let (stream, source) = AsyncStream<Value>.makeStream()
        subSource.yield(.add(id, source))
        return (stream, id)
    }

    nonisolated func removeSubsciber(_ id: SubscriptionID) {
        subSource.yield(.remove(id))
    }

    func run() async throws {
        try await withGracefulShutdownHandler {
            for try await command in self.subStream {
                switch command {
                case .add(let id, let source):
                    await self._addSubsciber(id, source: source)
                case .remove(let id):
                    self._removeSubsciber(id)
                }
            }
        } onGracefulShutdown: {
            self.subSource.finish()
        }
    }

    private func _addSubsciber(_ id: SubscriptionID, source: AsyncStream<Value>.Continuation) async {
        self.subscriptions[id] = source
    }

    private func _removeSubsciber(_ id: SubscriptionID) {
        self.subscriptions[id]?.finish()
        self.subscriptions[id] = nil
    }

    var subscriptions: [UUID: AsyncStream<Value>.Continuation]
}
