import Hummingbird
import HummingbirdJobs

struct SendMessageJob: HBJob {
    static var maxRetryCount: Int = 1

    static var name: String = "SendMessage"

    let message: String

    func execute(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Void> {
        logger.info("\(self.message)")
        return eventLoop.makeSucceededVoidFuture()
    }
}
