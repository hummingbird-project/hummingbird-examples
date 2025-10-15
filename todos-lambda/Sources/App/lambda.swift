//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AsyncHTTPClient
import AWSLambdaEvents
import AWSLambdaRuntime
import HummingbirdLambda
import Logging
import SotoDynamoDB

/// The main entry point for this app. In the main function, create a Hummingbird router
/// using a context, and provide it to the `APIGatewayLambdaFunction`.
///
/// Note: This sample project uses the `@main` attribute and a dedicated type, `App`,
/// to organize the code in a cleaner way. Alternatively, if you want a smaller approach, add the snippet in
/// the [Hummingbird-Lambda package's
/// readme](https://github.com/hummingbird-project/hummingbird-lambda) to the
/// target's main.swift file instead.
@main
struct App {
    /// The Context for your application. All Lambda functions need a LambdaRequestContext conforming type.
    /// 
    /// It's common to define a typealias for your preferred Context type. That way you can change the
    /// Context type if you need to, and only have to change one line of code.
    ///
    /// **Important:** this sample project uses API Gateway to expose the function to the web, and
    ///  and therefore the request context uses `APIGatewayRequest`. In case you use the
    ///  simpler function URL instead, change the APIGatewayRequest in your context to
    ///  a `FunctionURLRequest`, and the lambda to `FunctionURLLambdaFunction`.
    ///  The same applies to API Gateway V2.
    typealias Context = BasicLambdaRequestContext<APIGatewayRequest>

    private let awsClient: AWSClient
    private let logger: Logger

    /// Initializes the App struct, builds the router, and run the lambda using the router.
    static func main() async throws {
        let app = App()
        let router = app.buildRouter()
        let lambda = APIGatewayLambdaFunction(router: router)
        try await lambda.runService()

        // Shut down the AWS client and other services after the lambda
        // is done
        try await app.shutdown()
    }

    init() {
        self.awsClient = AWSClient(httpClient: HTTPClient.shared)
        self.logger = Logger(label: "Todos Lambda")
    }

    /// Builds a Router, which is responsible for handling requests.
    /// A Hummingbird Router is the most common responder, and is used in this example,
    /// as it is required to initialize a .
    ///
    /// If you want your Hummingbird application to be flexibly deployed as either a Lambda or a normal HTTP server,
    /// you should extract your Router creation, business logic and dependencies into a separate target.
    /// Then you can use that module in your lambda function and "normal" HTTP Server-based Application.
    func buildRouter() -> Router<Context> {
        // Reads the Environment variables for the table name
        let env = Environment()
        let tableName = env.get("TODOS_TABLE_NAME") ?? "hummingbird-todos"
        logger.info("Using table \(tableName)")

        // Creates a DynamoDB client
        let dynamoDB = DynamoDB(client: awsClient, region: .euwest1)

        // Creates a Router, using our context (defined as a typealias above)
        let router = Router(context: Context.self)

        // Middleware
        router.add(middleware: ErrorMiddleware())
        router.add(middleware: LogRequestsMiddleware(.debug))
        router.get("/") { _, _ in
            "Hello from Lambda + Hummingbird"
        }

        // When enabling Lambda function URLs, CORS can be configured at the AWS level, and there's
        // no need for this middleware.
        // If you prefer to manage CORS internally instead, use this:
        router.add(middleware: CORSMiddleware(
            allowOrigin: .originBased,
            allowHeaders: [.contentType],
            allowMethods: [.get, .options, .post, .delete, .patch]
        ))

        // Adds the TodoController to the router
        TodoController(
            dynamoDB: dynamoDB,
            tableName: tableName
        ).addRoutes(to: router.group("todos"))

        return router
    }

    /// Shuts down the AWS Lambda runtime.
    /// Call this function after the lambda function is being terminated.
    /// You can add here any other resources that need to be cleaned up.
    func shutdown() async throws {
        try await awsClient.shutdown()
    }
}

/// A middleware that handles errors.
/// This is a simple example, and translates unknown errors into a 500 error.
/// By being generic over any RequestContext, this middleware can be used regardless of the type of RequestContext.
struct ErrorMiddleware<Context: RequestContext>: RouterMiddleware {
    func handle(
        _ input: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        do {
            return try await next(input, context)
        } catch let error as HTTPError {
            throw error
        } catch {
            throw HTTPError(.internalServerError, message: "Error: \(error)")
        }
    }
}
