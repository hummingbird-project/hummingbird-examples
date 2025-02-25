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

    let emailService: FakeEmailService
    init(emailService: FakeEmailService) {
        self.emailService = emailService
    }

    func registerJobs(on queue: some JobQueueProtocol) {
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
