import FluentKit
import Foundation
import Hummingbird
import HummingbirdAuth

struct SessionAuthenticator: HBAuthenticator {
    func authenticate(request: HBRequest) -> EventLoopFuture<Void> {
        // check if session exists in the database. If it is login related user
        return request.session.load().flatMap { session in
            guard let session = session,
                  session.expires.timeIntervalSinceNow > 0 else {
                return request.success(())
            }
            return User.find(session.userId, on: request.db)
                .map { user in
                    if let user = user {
                        request.auth.login(user)
                    }
                }
        }
    }

    /// Add repeating task to cleanup expired session entries
    static func scheduleTidyUp(application: HBApplication) {
/*        let eventLoop = application.eventLoopGroup.next()
        eventLoop.scheduleRepeatedAsyncTask(initialDelay: .seconds(1), delay: .hours(1)) { _ in
            return
                Session.query(on: application.db)
                    .count()
                    .map {
                        application.logger.info("Count before tidy up \($0)")
                    }
                    .flatMap { _ in
                        Session.query(on: application.db)
                        .filter(\.$expires < Date())
                        .delete()
                    }
                    .flatMap { _ in
                        Session.query(on: application.db)
                            .count()
                            .map {
                                application.logger.info("Count after tidy up \($0)")
                            }
                    }
        }*/
    }
}
