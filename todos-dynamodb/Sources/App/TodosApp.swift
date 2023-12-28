import Hummingbird
import HummingbirdFoundation
import NIOCore
import NIOPosix
import ServiceLifecycle
import SotoDynamoDB

struct TodosApp: HBApplicationProtocol {
    /// Request context which default to using JSONDecoder/Encoder
    struct Context: HBRequestContext {
        init(allocator: ByteBufferAllocator, logger: Logger) {
            self.coreContext = .init(
                requestDecoder: JSONDecoder(),
                responseEncoder: JSONEncoder(),
                allocator: allocator,
                logger: logger
            )
        }

        var coreContext: HBCoreRequestContext
    }

    init(configuration: HBApplicationConfiguration, eventLoopGroupProvider: EventLoopGroupProvider = .singleton) {
        self.configuration = configuration
        self.eventLoopGroup = eventLoopGroupProvider.eventLoopGroup
        self.awsClient = AWSClient(httpClientProvider: .createNewWithEventLoopGroup(self.eventLoopGroup))
    }

    var responder: some HBResponder<Context> {
        let router = HBRouter(context: Context.self)
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

        let dynamoDB = DynamoDB(client: awsClient, region: .euwest1)

        let todoController = TodoController(dynamoDB: dynamoDB)
        todoController.addRoutes(to: router.group("todos"))

        return router.buildResponder()
    }

    let awsClient: AWSClient
    let configuration: HBApplicationConfiguration
    let eventLoopGroup: EventLoopGroup
    var services: [any Service] { [self.awsClient] }
}
