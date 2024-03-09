import HummingbirdJobs

struct JobController {
    // parameters required to run email job
    struct EmailParameters: Codable {
        let to: [String]
        let from: String
        let subject: String
        let message: String
    }

    init(queue: borrowing HBJobQueue<some HBJobQueueDriver>, emailService: FakeEmailService) {
        // This function demonstrates two different ways to register a job
        // Register Job with predefined job identifier
        queue.registerJob(.sendEmail) { parameters, context in
            try await emailService.sendEmail(
                to: parameters.to,
                from: parameters.from,
                subject: parameters.subject,
                message: parameters.message
            )
        }

        // Create job definition and extract job id from it
        let emailJob = HBJobDefinition(id: "send_email_2") { (parameters: EmailParameters, context) in
            try await emailService.sendEmail(
                to: parameters.to,
                from: parameters.from,
                subject: parameters.subject,
                message: parameters.message
            )
        }
        queue.registerJob(emailJob)
        self.emailJobId = emailJob.id
    }

    let emailJobId: HBJobIdentifier<EmailParameters>
}

extension HBJobIdentifier<JobController.EmailParameters> {
    /// Job ID used by send email job
    static var sendEmail: Self { .init("send_email") }
}
