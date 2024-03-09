import Logging

struct FakeEmailService {
    let logger: Logger

    func sendEmail(to: [String], from: String, subject: String, message: String) async throws {
        self.logger.info("To: \(to.joined(separator: ", "))")
        self.logger.info("From: \(from)")
        self.logger.info("Subject: \(subject)")
        self.logger.info("\(message)")
    }
}
