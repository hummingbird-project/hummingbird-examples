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

/// The main entry point for the lambda function.
/// The conformance to `APIGatewayLambdaFunction` sets up the AWS Lambda runtime and Hummingbird Application for you.
/// You just need to implement the `buildResponder` function to handle requests.
/// Alternatively, you can use the `APIGatewayV2LambdaFunction` conformance to build a Lambda function for APIGatewayV2.
@main
struct AppLambda: APIGatewayLambdaFunction {
    /// The Context for your application. All Lambda functions needa LambdaRequestContext conforming type.
    /// The default type for a Lambda function is `BasicLambdaRequestContext<APIGatewayRequest>`.
    /// or `BasicLambdaRequestContext<APIGatewayV2Request>` for APIGatewayV2 services.
    /// 
    /// It's common to define a typealias for your preferred Context type. That way you can change the Context type
    /// if you need to, and only have to change one line of code.
    typealias Context = BasicLambdaRequestContext<APIGatewayRequest>
    
    let awsClient: AWSClient
    let logger: Logger

    /// Initialized the Lambda function. This is called when the lambda function is first spun up.
    /// We initialize the AWS client and logger here. You can also initialize any other services here.
    /// For example, Logging, Metrics and Tracing should be set up here.
    init(context: LambdaInitializationContext) {
        self.awsClient = AWSClient(httpClient: HTTPClient.shared)
        self.logger = context.logger
    }

    /// Builds a Responder, which is responsible for handling requests.
    /// A Hummingbird Router is the most common responder, and is used in this example.
    /// 
    /// If you want your Hummingbird application to be flexibly deployed as either a Lambda or a normal HTTP server,
    /// you should extract your Responder, business logic and dependencies into a separate module.
    /// Then you can use that module in your lambda function and "normal" HTTP Server-based Application.
    func buildResponder() -> some HTTPResponder<Context> {
        // Reads the Environment variables for the table name
        let env = Environment()
        let tableName = env.get("TODOS_TABLE_NAME") ?? "hummingbird-todos"
        self.logger.info("Using table \(tableName)")

        // Creates a DynamoDB client
        let dynamoDB = DynamoDB(client: awsClient, region: .euwest1)

        // Creates a Router. Thsis uses our preferred context.
        let router = Router(context: Context.self)
        // middleware
        router.add(middleware: ErrorMiddleware())
        router.add(middleware: LogRequestsMiddleware(.debug))
        router.get("/") { _, _ in
            return "Hello"
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
        TodoController(dynamoDB: dynamoDB, tableName: tableName).addRoutes(to: router.group("todos"))

        return router.buildResponder()
    }

    /// Shuts down the AWS Lambda runtime.
    /// This is called when the lambda function is being terminated.
    /// Any resources that need to be cleaned up should be cleaned up here.
    func shutdown() async throws {
        try await self.awsClient.shutdown()
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
