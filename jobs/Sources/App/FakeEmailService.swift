import Logging

struct FakeEmailService {
    let logger: Logger

    func sendEmail(to: [String], from: String, subject: String, message: String) async throws {
        self.logger.info("Sending email from: \(from) to: \(to.joined(separator: ", "))")
        self.logger.info("Subject: \(subject)")
        try await Task.sleep(for: .milliseconds(50))
    }
}
