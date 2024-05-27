import AsyncHTTPClient
import Hummingbird
import NIOCore
import NIOPosix
import ServiceLifecycle
import SotoDynamoDB

struct TodosApp: ApplicationProtocol {
    typealias Context = BasicRequestContext

    init(
        configuration: ApplicationConfiguration
    ) {
        self.configuration = configuration
        self.awsClient = AWSClient(httpClient: HTTPClient.shared)
    }

    var responder: some HTTPResponder<Context> {
        let router = Router(context: Context.self)
        // middleware
        router.middlewares.add(LogRequestsMiddleware(.debug))
        router.middlewares.add(CORSMiddleware(
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
    let configuration: ApplicationConfiguration
    var services: [any Service] { [self.awsClient] }
}
