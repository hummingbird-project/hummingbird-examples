//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2022 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Hummingbird
import HummingbirdJobsRedis
import HummingbirdRedis

public protocol AppArguments {
    var useMemory: Bool { get }
    var processJobs: Bool { get }
}

extension HBApplication {
    /// configure your application
    /// add middleware
    /// setup the encoder/decoder
    /// add your routes
    public func configure(_ arguments: AppArguments) throws {
        let env = HBEnvironment()

        // Register SendMessageJob
        SendMessageJob.register()

        // store jobs in memory
        if arguments.useMemory {
            self.addJobs(using: .memory, numWorkers: 4)
        } else {
            try self.addRedis(
                configuration: .init(
                    hostname: env.get("REDIS_HOST") ?? "localhost",
                    port: 6379,
                    pool: .init(connectionRetryTimeout: .seconds(1))
                )
            )
            self.addJobs(
                using: .redis(configuration: .init(queueKey: "_JobsExample", rerunProcessing: true)),
                numWorkers: arguments.processJobs ? 4 : 0
            )
        }
        router.post("/send") { request -> EventLoopFuture<HTTPResponseStatus> in
            guard let body = request.body.buffer else { return request.failure(HBHTTPError(.badRequest)) }
            return request.jobs.enqueue(job: SendMessageJob(message: String(buffer: body))).map { _ in .ok }
        }
    }
}
