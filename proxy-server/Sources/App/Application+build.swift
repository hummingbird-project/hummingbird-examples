import AsyncHTTPClient
import Hummingbird
import Logging
import NIOCore
import NIOPosix
import ServiceLifecycle

public protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var location: String { get }
    var target: String { get }
}

/// Request context for proxy
///
/// Stores remote address
struct ProxyRequestContext: RequestContext {
    var coreContext: CoreRequestContextStorage
    let remoteAddress: SocketAddress?

    init(source: Source) {
        self.coreContext = .init(source: source)
        self.remoteAddress = source.channel.remoteAddress
    }
}

func buildApplication(_ args: some AppArguments) -> some ApplicationProtocol {
    let eventLoopGroup = MultiThreadedEventLoopGroup.singleton
    let httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
    let router = Router(context: ProxyRequestContext.self)
    router.add(middleware:
        ProxyServerMiddleware(
            httpClient: httpClient,
            proxy: .init(location: args.location, target: args.target)
        )
    )
    var app = Application(
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
