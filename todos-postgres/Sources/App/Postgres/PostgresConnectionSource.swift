import Hummingbird
import Logging
import PostgresNIO

extension PostgresConnection: HBAsyncConnection {}

struct PostgresConnectionSource: HBAsyncConnectionSource {
    typealias Connection = PostgresConnection
    
    let configuration: Connection.Configuration

    init(configuration: Connection.Configuration) {
        self.configuration = configuration
    }

    func makeConnection(on eventLoop: EventLoop, logger: Logger) async throws -> Connection {
        let connection = try await PostgresConnection.connect(on: eventLoop, configuration: self.configuration, id: 0, logger: logger)
        return connection
    }
}

