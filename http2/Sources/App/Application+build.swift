import Hummingbird
import HummingbirdHTTP2
import Logging
import NIOCore
import NIOHTTP2

public protocol AppArguments {
    var tlsConfiguration: TLSConfiguration { get throws }
}

struct ChannelRequestContext: RequestContext {
    init(source: Source) {
        self.coreContext = .init(source: source)
        self.channel = source.channel
    }

    var isHTTP2: Bool {
        // Using the fact that HTTP2 stream channels have a parent HTTP2 connection channel
        // as a way to recognise an HTTP/2 channel vs an HTTP/1.1 channel
        self.channel.parent?.parent != nil
    }

    var coreContext: CoreRequestContextStorage
    let channel: Channel
}

func buildApplication(arguments: some AppArguments, configuration: ApplicationConfiguration) throws
    -> some ApplicationProtocol
{
    let router = Router(context: ChannelRequestContext.self)
    router.add(middleware: FileMiddleware(searchForIndexHtml: true))
    router.get("/http") { request, context in
        return "Using http v\(context.isHTTP2 ? "2.0" : "1.1")"
    }

    let app = try Application(
        router: router,
        server: .http2Upgrade(
            tlsConfiguration: arguments.tlsConfiguration,
            configuration: .init(
                idleTimeout: .seconds(30),
                gracefulCloseTimeout: .seconds(30),
                maxAgeTimeout: .seconds(2 * 60 * 60)
            )
        ),
        configuration: configuration
    )
    return app
}
