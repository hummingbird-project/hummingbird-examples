import FluentKit
import Foundation
import Hummingbird
import HummingbirdAuth

struct SessionAuthenticator: HBAuthenticator {
    func authenticate(request: HBRequest) -> EventLoopFuture<User?> {
        // does request have session cookie
        guard let sessionId = request.session.getId() else { return request.success(nil) }

        // check if session exists in the database. If it is login related user
        return Session.query(on: request.db).with(\.$user)
            .filter(\.$id == sessionId)
            .first()
            .map { session -> User? in
                guard let session = session else { return nil }
                // has session expired
                if session.expires.timeIntervalSinceNow > 0 {
                    return session.user
                }
                return nil
            }
            // hop back to request eventloop
            .hop(to: request.eventLoop)
    }

    /// Add repeating task to cleanup expired session entries
    static func scheduleTidyUp(application: HBApplication) {
        let eventLoop = application.eventLoopGroup.next()
        eventLoop.scheduleRepeatedAsyncTask(initialDelay: .seconds(1), delay: .hours(1)) { _ in
            return Session.query(on: application.db)
                .filter(\.$expires < Date())
                .delete()
        }
    }
}
