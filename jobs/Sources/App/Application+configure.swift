import Hummingbird
import HummingbirdJobsRedis
import HummingbirdRedis

public protocol AppArguments {
    var processJobs: Bool { get }
}

extension HBApplication {
    /// configure your application
    /// add middleware
    /// setup the encoder/decoder
    /// add your routes
    public func configure(_ arguments: AppArguments) throws {
        SendMessageJob.register()

        try self.addRedis(
            configuration: .init(
                hostname: "localhost",
                port: 6379,
                pool: .init(connectionRetryTimeout: .seconds(1))
            )
        )
        self.addJobs(
            using: .redis(configuration: .init(queueKey: "_JobsExample", rerunProcessing: true)),
            numWorkers: arguments.processJobs ? 4 : 0
        )

        router.post("/send") { request -> EventLoopFuture<HTTPResponseStatus> in
            guard let body = request.body.buffer else { return request.failure(HBHTTPError(.badRequest)) }
            return request.jobs.enqueue(job: SendMessageJob(message: String(buffer: body))).map { _ in .ok }
        }
    }
}
