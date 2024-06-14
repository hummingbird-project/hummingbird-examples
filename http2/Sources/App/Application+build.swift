import Hummingbird
import HummingbirdHTTP2
import Logging
import NIOCore
import NIOHTTPTypesHTTP2

public protocol AppArguments {
    var tlsConfiguration: TLSConfiguration { get throws }
}

struct ChannelRequestContext: RequestContext {
    init(source: Source) {
        self.coreContext = .init(source: source)
        self.channel = source.channel
    }

    var hasHTTP2Handler: Bool {
        get async {
            if let channel = self.channel {
                return (try? await channel.pipeline.handler(type: HTTP2FramePayloadToHTTPServerCodec.self).get()) != nil
            }
            return false
        }
    }

    var coreContext: CoreRequestContext
    let channel: Channel?
}

import Hummingbird

func buildApplication(arguments: some AppArguments, configuration: ApplicationConfiguration) throws -> some ApplicationProtocol {
    let router = Router(context: ChannelRequestContext.self)
    router.get("/http") { _, context in
        // return "Using http v\(request.head. == "h2" ? "2.0" : "1.1")"
        return "Using http v\(await context.hasHTTP2Handler ? "2.0" : "1.1")"
    }

    let app = try Application(
        router: router,
        server: .http2Upgrade(tlsConfiguration: arguments.tlsConfiguration),
        configuration: configuration
    )
    return app
}
