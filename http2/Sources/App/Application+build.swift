import Hummingbird
import HummingbirdHTTP2
import Logging
import NIOCore
import NIOHTTPTypesHTTP2

public protocol AppArguments {
    var tlsConfiguration: TLSConfiguration { get throws }
}

struct ChannelRequestContext: HBRequestContext {
    init(allocator: ByteBufferAllocator, logger: Logger) {
        self.coreContext = .init(allocator: allocator, logger: logger)
        self.channel = nil
    }

    init(channel: Channel, logger: Logger) {
        self.coreContext = .init(allocator: channel.allocator, logger: logger)
        self.channel = channel
    }

    var hasHTTP2Handler: Bool {
        get async {
            if let channel = self.channel {
                return (try? await channel.pipeline.handler(type: HTTP2FramePayloadToHTTPServerCodec.self).get()) != nil
            }
            return false
        }
    }

    var coreContext: HBCoreRequestContext
    let channel: Channel?
}

import Hummingbird

func buildApplication(arguments: some AppArguments, configuration: HBApplicationConfiguration) throws -> some HBApplicationProtocol {
    let router = HBRouter(context: ChannelRequestContext.self)
    router.get("/http") { _, context in
        // return "Using http v\(request.head. == "h2" ? "2.0" : "1.1")"
        return "Using http v\(await context.hasHTTP2Handler ? "2.0" : "1.1")"
    }

    let app = try HBApplication(
        router: router,
        server: .http2(tlsConfiguration: arguments.tlsConfiguration),
        configuration: configuration
    )
    return app
}
