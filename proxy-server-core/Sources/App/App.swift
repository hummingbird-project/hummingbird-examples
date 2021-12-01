import ArgumentParser
import AsyncHTTPClient
import HummingbirdCore
import Logging
import NIOCore
import NIOPosix

@main
struct ProxyServer: ParsableCommand {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 8081

    @Option(name: .shortAndLong)
    var target: String = "http://localhost:8080"

    func run() throws {
        // setup proxy server responder
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
        var logger = Logger(label: "proxy")
        logger.logLevel = .info
        let responder = HTTPProxyServer(
            targetServer: self.target,
            httpClient: httpClient,
            logger: logger
        )
        // create server and start it
        let server = HBHTTPServer(group: eventLoopGroup, configuration: .init(address: .hostname(self.hostname, port: self.port)))
        try server.start(responder: responder).wait()
        try server.wait()
    }
}
