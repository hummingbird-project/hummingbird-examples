import Hummingbird
import Logging
import PostgresNIO

extension PSQLConnection: HBAsyncConnection {}

struct PostgresConnectionSource: HBAsyncConnectionSource {
    typealias Connection = PSQLConnection
    
    let configuration: PSQLConnection.Configuration

    init(configuration: PSQLConnection.Configuration) {
        self.configuration = configuration
    }

    func makeConnection(on eventLoop: EventLoop, logger: Logger) async throws -> PSQLConnection {
        let connection = try await PSQLConnection.connect(configuration: self.configuration, logger: logger, on: eventLoop)
        return connection
    }
}

