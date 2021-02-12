import FluentKit
import Foundation
import Hummingbird
import HummingbirdAuth

struct SessionAuthenticator: HBAuthenticator {
    func authenticate(request: HBRequest) -> EventLoopFuture<User?> {
        return request.session.load()
            // hop back to request eventloop
            .hop(to: request.eventLoop)
    }

    /// Add repeating task to cleanup expired session entries
    static func scheduleTidyUp(application: HBApplication) {
        let eventLoop = application.eventLoopGroup.next()
        eventLoop.scheduleRepeatedAsyncTask(initialDelay: .seconds(1), delay: .hours(1)) { _ in
            return SessionData.query(on: application.db)
                .filter(\.$expires < Date())
                .delete()
        }
    }
}
