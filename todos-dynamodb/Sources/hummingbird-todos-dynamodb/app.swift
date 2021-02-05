import Foundation
import Hummingbird
import HummingbirdFoundation
import SotoDynamoDB

func runApp(_ arguments: HummingbirdArguments) throws {
    let app = HBApplication(configuration: .init(address: .hostname(arguments.hostname, port: arguments.port)))
    // set encoder and decoder
    app.encoder = JSONEncoder()
    app.decoder = JSONDecoder()
    
    app.middleware.add(DebugMiddleware())
    app.middleware.add(CORSMiddleware())

    app.aws.client = AWSClient(httpClientProvider: .createNewWithEventLoopGroup(app.eventLoopGroup))
    app.aws.dynamoDB = DynamoDB(client: app.aws.client, region: .euwest1)
    
    app.router.get("/") { _ in
        return "Hello"
    }
    let todoController = TodoController()
    todoController.addRoutes(to: app.router.group("todos"))

    app.start()
    app.wait()
}
