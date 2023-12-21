import Hummingbird
import HummingbirdFoundation
import NIOCore
import NIOPosix
import SotoDynamoDB

/// Request context which default to using JSONDecoder/Encoder
struct TodosRequestContext: HBRequestContext {
    init(eventLoop: EventLoop, allocator: ByteBufferAllocator, logger: Logger) {
        self.coreContext = .init(
            requestDecoder: JSONDecoder(),
            responseEncoder: JSONEncoder(),
            eventLoop: eventLoop,
            allocator: allocator,
            logger: logger
        )
    }

    var coreContext: HBCoreRequestContext
}

public func buildApplication(configuration: HBApplicationConfiguration) -> some HBApplicationProtocol {
    let router = HBRouter(context: TodosRequestContext.self)
    // middleware
    router.middlewares.add(HBLogRequestsMiddleware(.debug))
    router.middlewares.add(HBCORSMiddleware(
        allowOrigin: .originBased,
        allowHeaders: [.contentType],
        allowMethods: [.get, .options, .post, .delete, .patch]
    ))
    router.get("/") { _, _ in
        return "Hello"
    }

    let eventLoopGroup = MultiThreadedEventLoopGroup.singleton
    let awsClient = AWSClient(httpClientProvider: .createNewWithEventLoopGroup(eventLoopGroup))
    let dynamoDB = DynamoDB(client: awsClient, region: .euwest1)

    let todoController = TodoController(dynamoDB: dynamoDB)
    todoController.addRoutes(to: router.group("todos"))

    var app = HBApplication(
        responder: router.buildResponder(),
        channelSetup: .http1(),
        configuration: configuration,
        eventLoopGroupProvider: .singleton
    )
    app.addService(awsClient)
    return app
}
