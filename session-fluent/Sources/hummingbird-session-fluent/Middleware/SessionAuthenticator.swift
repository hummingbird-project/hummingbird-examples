import FluentKit
import Foundation
import Hummingbird
import HummingbirdAuth

struct SessionAuthenticator: HBAuthenticator {
    func authenticate(request: HBRequest) -> EventLoopFuture<Void> {
        // does request have session cookie
        guard let sessionId = request.session.getId() else { return request.success(()) }

        // check if session exists in the database. If it is login related user
        return Session.query(on: request.db).with(\.$user)
            .filter(\.$id == sessionId)
            .first()
            .map { session -> Void in
                guard let session = session else { return }
                if Date() < session.expires {
                    request.auth.login(session.user)
                }
            }
            // hop back to request eventloop
            .hop(to: request.eventLoop)
    }
}
