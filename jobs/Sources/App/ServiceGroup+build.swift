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
import Jobs
import JobsRedis
import HummingbirdRedis
import Logging
import ServiceLifecycle

public protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var processJobs: Bool { get }
}

func buildServiceGroup(_ args: AppArguments) throws -> ServiceGroup {
    let env = Environment()
    let redisHost = env.get("REDIS_HOST") ?? "localhost"
    let logger = {
        var logger = Logger(label: "JobsExample")
        logger.logLevel = .info
        return logger
    }()

    let redisService = try RedisConnectionPoolService(
        .init(hostname: redisHost, port: 6379),
        logger: logger
    )
    let jobQueue = JobQueue(
        .redis(redisService.pool),
        numWorkers: 4,
        logger: logger
    )
    let jobController = JobController(queue: jobQueue, emailService: .init(logger: logger))

    if !args.processJobs {
        let router = Router()
        router.post("/send") { request, context -> HTTPResponse.Status in
            let message = try await request.body.collect(upTo: 2048)
            try await jobQueue.push(
                JobController.EmailParameters(
                    to: ["john@email.com"],
                    from: "jane@email.com",
                    subject: "HI!",
                    message: """
                    Hi John,

                    \(String(buffer: message))

                    From
                    Jane
                    """
                )
            )
            return .ok
        }
        router.post("/send2") { request, context -> HTTPResponse.Status in
            let message = try await request.body.collect(upTo: 2048)
            try await jobQueue.push(
                id: jobController.emailJobId,
                parameters: .init(
                    to: ["jane@email.com"],
                    from: "john@email.com",
                    subject: "HI!",
                    message: """
                    Hi Jane,

                    \(String(buffer: message))

                    From
                    John
                    """
                )
            )
            return .ok
        }
        let app = Application(
            router: router,
            configuration: .init(address: .hostname(args.hostname, port: args.port))
        )
        return ServiceGroup(
            configuration: .init(
                services: [redisService, app],
                gracefulShutdownSignals: [.sigterm, .sigint],
                logger: logger
            )
        )
    } else {
        return ServiceGroup(
            configuration: .init(
                services: [redisService, jobQueue],
                gracefulShutdownSignals: [.sigterm, .sigint],
                logger: logger
            )
        )
    }
}
