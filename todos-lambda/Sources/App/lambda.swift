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

import AWSLambdaEvents
import AWSLambdaRuntime
import HummingbirdLambda
import Logging
import SotoDynamoDB

@main
struct AppLambda: HBAPIGatewayLambda {
    let awsClient: AWSClient
    let logger: Logger

    init(context: LambdaInitializationContext) {
        self.awsClient = AWSClient(httpClientProvider: .createNewWithEventLoopGroup(context.eventLoop))
        self.logger = context.logger
    }

    func buildResponder() -> some HBResponder<Context> {
        let tableName = HBEnvironment.shared.get("TODOS_TABLE_NAME") ?? "hummingbird-todos"
        self.logger.info("Using table \(tableName)")
        let dynamoDB = DynamoDB(client: awsClient, region: .euwest1)

        let router = HBRouter(context: Context.self)
        // middleware
        router.middlewares.add(ErrorMiddleware())
        router.middlewares.add(HBLogRequestsMiddleware(.debug))
        router.get("/") { _, _ in
            return "Hello"
        }
        router.middlewares.add(HBCORSMiddleware(
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

struct ErrorMiddleware<Context: HBBaseRequestContext>: HBMiddlewareProtocol {
    func handle(
        _ input: HBRequest,
        context: Context,
        next: (HBRequest, Context) async throws -> HBResponse
    ) async throws -> HBResponse {
        do {
            return try await next(input, context)
        } catch let error as HBHTTPError {
            throw error
        } catch {
            throw HBHTTPError(.internalServerError, message: "Error: \(error)")
        }
    }
}
