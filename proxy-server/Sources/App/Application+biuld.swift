import AsyncHTTPClient
import Hummingbird
import NIOPosix
import ServiceLifecycle

public protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var location: String { get }
    var target: String { get }
}

func buildApplication(_ args: some AppArguments) -> some HBApplicationProtocol {
    let eventLoopGroup = MultiThreadedEventLoopGroup.singleton
    let httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
    let router = HBRouter()
    router.middlewares.add(
        HBProxyServerMiddleware(
            httpClient: httpClient,
            proxy: .init(location: args.location, target: args.target)
        )
    )
    var app = HBApplication(
        router: router,
        configuration: .init(
            address: .hostname(args.hostname, port: args.port),
            serverName: "ProxyServer"
        ),
        eventLoopGroupProvider: .shared(eventLoopGroup)
    )
    app.addServices(HTTPClientService(client: httpClient))
    return app
}

struct HTTPClientService: Service {
    let client: HTTPClient

    func run() async throws {
        try? await gracefulShutdown()
        try await self.client.shutdown()
    }
}
