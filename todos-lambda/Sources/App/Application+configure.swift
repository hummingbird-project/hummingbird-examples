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
import NIO
import SotoDynamoDB

extension HBApplication {
    /// configure your application
    /// add middleware
    /// setup the encoder/decoder
    /// add your routes
    public func configure() throws {
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
