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
import HummingbirdRedis
import Jobs
import JobsRedis
import Logging
import ServiceLifecycle

public protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var processJobs: Bool { get }
    var logLevel: Logger.Level? { get }
}

func buildServiceGroup(_ args: AppArguments) async throws -> ServiceGroup {
    let env = Environment()
    let redisHost = env.get("REDIS_HOST") ?? "localhost"
    let logger = {
        var logger = Logger(label: "Jobs")
        logger.logLevel =
            args.logLevel ?? env.get("LOG_LEVEL").flatMap { Logger.Level(rawValue: $0) } ?? .info
        return logger
    }()
    let redisLogger = Logger(label: "Redis")
    let redisService = try RedisConnectionPoolService(
        .init(hostname: redisHost, port: 6379),
        logger: redisLogger
    )
    let jobQueue = try await JobQueue(
        .redis(
            redisService.pool,
            configuration: .init(queueName: "HBExample", retentionPolicy: .init(completedJobs: .retain)),
            logger: logger
        ),
        logger: logger
    )
    _ = JobController(queue: jobQueue, emailService: .init(logger: logger))

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
        var jobSchedule = JobSchedule()
        jobSchedule.addJob(
            jobQueue.queue.cleanupJob,
            parameters: .init(completedJobs: .remove(maxAge: .seconds(24 * 60 * 60))),
            schedule: .hourly(minute: 52)
        )
        return await ServiceGroup(
            configuration: .init(
                services: [
                    redisService,
                    jobQueue.processor(options: .init(numWorkers: 4, gracefulShutdownTimeout: .seconds(10))),
                    jobSchedule.scheduler(on: jobQueue, named: "HBExample"),
                ],
                gracefulShutdownSignals: [.sigterm, .sigint],
                logger: logger
            )
        )
    }
}
