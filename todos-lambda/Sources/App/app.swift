//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
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
import HummingbirdFoundation
import HummingbirdLambda
import NIO
import SotoDynamoDB

public typealias AppHandler = HBLambdaHandler<TodosLambda>

public struct TodosLambda: HBLambda {
    public typealias In = APIGateway.Request
    public typealias Out = APIGateway.Response

    public init(_ app: HBApplication) {
        app.encoder = JSONEncoder()
        app.decoder = JSONDecoder()
        // middleware
        app.middleware.add(HBLogRequestsMiddleware(.debug))
        app.middleware.add(HBCORSMiddleware(
            allowOrigin: .originBased,
            allowHeaders: ["Content-Type"],
            allowMethods: [.GET, .OPTIONS, .POST, .DELETE, .PATCH]
        ))

        app.aws.client = AWSClient(httpClientProvider: .createNewWithEventLoopGroup(app.eventLoopGroup))
        app.aws.dynamoDB = DynamoDB(client: app.aws.client, region: .euwest1)

        app.router.get("/") { _ in
            return "Hello"
        }
        let todoController = TodoController()
        todoController.addRoutes(to: app.router.group("todos"))
    }
}
