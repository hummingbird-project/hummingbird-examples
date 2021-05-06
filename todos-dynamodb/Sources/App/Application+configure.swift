import Hummingbird
import HummingbirdFoundation
import SotoDynamoDB

extension HBApplication {
    /// configure your application
    /// add middleware
    /// setup the encoder/decoder
    /// add your routes
    public func configure() throws {
        // set encoder and decoder
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        // middleware
        self.middleware.add(HBLogRequestsMiddleware(.debug))
        self.middleware.add(HBCORSMiddleware(
            allowOrigin: .originBased,
            allowHeaders: ["Content-Type"],
            allowMethods: [.GET, .OPTIONS, .POST, .DELETE, .PATCH]
        ))

        self.aws.client = AWSClient(httpClientProvider: .createNewWithEventLoopGroup(self.eventLoopGroup))
        self.aws.dynamoDB = DynamoDB(client: self.aws.client, region: .euwest1)

        self.router.get("/") { _ in
            return "Hello"
        }
        let todoController = TodoController()
        todoController.addRoutes(to: self.router.group("todos"))
    }
}
