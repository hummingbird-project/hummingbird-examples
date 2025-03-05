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
import JobsPostgres
import JobsRedis
import Logging
import PostgresMigrations
import PostgresNIO
import ServiceLifecycle

public enum JobQueueDriverEnum: String, Codable {
    case postgres
    case redis
}
public protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var processJobs: Bool { get }
    var driver: JobQueueDriverEnum { get }
}

struct MigrationService: Service {
    let migrations: DatabaseMigrations
    let postgresClient: PostgresClient
    let logger: Logger
    let dryRun: Bool

    func run() async throws {
        try await migrations.apply(client: postgresClient, logger: logger, dryRun: dryRun)
        try? await gracefulShutdown()
    }
}

func buildServiceGroup(_ args: AppArguments) async throws -> ServiceGroup {
    let env = Environment()
    let redisHost = env.get("REDIS_HOST") ?? "localhost"
    let logger = {
        var logger = Logger(label: "JobsExample")
        logger.logLevel = .debug
        return logger
    }()

    let jobQueue: any JobQueueProtocol
    let servicesUsedByJobQueue: [any Service]
    switch args.driver {
    case .redis:
        var redisLogger = logger
        redisLogger.logLevel = .info
        let redisService = try RedisConnectionPoolService(
            .init(
                hostname: redisHost,
                port: 6379,
                pool: .init(maximumConnectionCount: .maximumPreservedConnections(32), connectionRetryTimeout: .seconds(60))
            ),
            logger: redisLogger
        )
        jobQueue = JobQueue(
            .redis(redisService.pool),
            numWorkers: 4,
            logger: logger
        ) {
            MetricsJobMiddleware()
        }
        servicesUsedByJobQueue = [redisService]
    case .postgres:
        let postgresClient = PostgresClient(
            configuration: .init(host: "127.0.0.1", port: 5432, username: "test_user", password: "test_password", database: "test_db", tls: .disable),
            backgroundLogger: logger
        )
        let postgresMigrations = DatabaseMigrations()
        jobQueue = await JobQueue(
            .postgres(client: postgresClient, migrations: postgresMigrations, logger: logger),
            numWorkers: 4,
            logger: logger
        ) {
            MetricsJobMiddleware()
        }
        servicesUsedByJobQueue = [
            postgresClient,
            MigrationService(migrations: postgresMigrations, postgresClient: postgresClient, logger: logger, dryRun: args.processJobs),
        ]
    }
    JobController(emailService: .init(logger: logger)).registerJobs(on: jobQueue)

    if !args.processJobs {
        let router = Router()
        router.get("/send") { request, context -> HTTPResponse.Status in
            let message = try await request.body.collect(upTo: 2048)
            do {
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
                    ),
                    options: .init()
                )
            } catch {
                print("\(error)")
                throw error
            }
            return .ok
        }
        let app = Application(
            router: router,
            configuration: .init(address: .hostname(args.hostname, port: args.port)),
            logger: logger
        )
        return ServiceGroup(
            configuration: .init(
                services: servicesUsedByJobQueue + [app, jobQueue],
                gracefulShutdownSignals: [.sigterm, .sigint],
                logger: logger
            )
        )
    } else {
        return ServiceGroup(
            configuration: .init(
                services: servicesUsedByJobQueue + [jobQueue],
                gracefulShutdownSignals: [.sigterm, .sigint],
                logger: logger
            )
        )
    }
}
