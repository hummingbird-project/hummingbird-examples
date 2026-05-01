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
import JobsValkey
import Logging
import ServiceLifecycle
import Valkey

public protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var processJobs: Bool { get }
    var logLevel: Logger.Level? { get }
}

func buildServiceGroup(_ args: AppArguments) async throws -> ServiceGroup {
    let env = Environment()
    let valkeyHost = env.get("VALKEY_HOST") ?? "localhost"
    let logger = {
        var logger = Logger(label: "Jobs")
        logger.logLevel =
            args.logLevel ?? env.get("LOG_LEVEL").flatMap { Logger.Level(rawValue: $0) } ?? .debug
        return logger
    }()
    let valkeyLogger = Logger(label: "Valkey")
    let valkeyClient = ValkeyClient(.hostname(valkeyHost, port: 6379), logger: valkeyLogger)
    let jobService = try await JobService(
        .valkey(
            valkeyClient,
            configuration: .init(queueName: "HBExample", retentionPolicy: .init(completedJobs: .retain)),
            logger: logger
        ),
        logger: logger,
        options: .init(
            processor: .init(numWorkers: 16, gracefulShutdownTimeout: .seconds(10)),
            scheduler: .init(schedulerLock: .acquire(every: .seconds(300), for: .seconds(360))),
            cleanup: .init(
                jobs: .init(
                    parameters: .init(completedJobs: .remove(maxAge: .seconds(10 * 60))),
                    schedule: .crontab("*/5 * * * *")
                )
            )
        )
    )
    _ = JobController(queue: jobService, emailService: .init(logger: logger))

    if !args.processJobs {
        let router = Router()
        // add route that creates a job
        router.post("/send") { request, context -> HTTPResponse.Status in
            let message = try await request.body.collect(upTo: 2048)
            try await jobService.push(
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
                services: [valkeyClient, app],
                gracefulShutdownSignals: [.sigterm, .sigint],
                logger: logger
            )
        )
    } else {
        // Create a ServiceGroup that includes the scheduler and the job queue processor. The scheduler is set
        // to acquire its lock so you can run multiple versions of the application but only one will ever schedule
        // jobs
        return ServiceGroup(
            configuration: .init(
                services: [
                    valkeyClient,
                    jobService,
                ],
                gracefulShutdownSignals: [.sigterm, .sigint],
                logger: logger
            )
        )
    }
}
