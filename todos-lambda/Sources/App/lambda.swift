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

@main
struct AppLambda: APIGatewayLambdaFunction {
    let awsClient: AWSClient
    let logger: Logger

    init(context: LambdaInitializationContext) {
        self.awsClient = AWSClient(httpClient: HTTPClient.shared)
        self.logger = context.logger
    }

    func buildResponder() -> some HTTPResponder<Context> {
        let tableName = Environment.shared.get("TODOS_TABLE_NAME") ?? "hummingbird-todos"
        self.logger.info("Using table \(tableName)")
        let dynamoDB = DynamoDB(client: awsClient, region: .euwest1)

        let router = Router(context: Context.self)
        // middleware
        router.add(middleware: ErrorMiddleware())
        router.add(middleware: LogRequestsMiddleware(.debug))
        router.get("/") { _, _ in
            return "Hello"
        }
        router.add(middleware: CORSMiddleware(
            allowOrigin: .originBased,
            allowHeaders: [.contentType],
            allowMethods: [.get, .options, .post, .delete, .patch]
        ))
        TodoController(dynamoDB: dynamoDB, tableName: tableName).addRoutes(to: router.group("todos"))

        return router.buildResponder()
    }

    func shutdown() async throws {
        try await self.awsClient.shutdown()
    }
}

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
