import Jobs

struct JobController {
    // parameters required to run email job
    struct EmailParameters: JobParameters {
        static let jobName = "send_email"
        let to: [String]
        let from: String
        let subject: String
        let message: String
    }

    init(queue: some JobQueueProtocol, emailService: FakeEmailService) {
        // This function demonstrates two different ways to register a job
        // Register Job with predefined job identifier
        queue.registerJob(parameters: EmailParameters.self) { parameters, context in
            try await emailService.sendEmail(
                to: parameters.to,
                from: parameters.from,
                subject: parameters.subject,
                message: parameters.message
            )
        }
    }
}
