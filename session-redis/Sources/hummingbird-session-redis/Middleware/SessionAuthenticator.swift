import FluentKit
import Foundation
import Hummingbird
import HummingbirdAuth

struct SessionAuthenticator: HBAuthenticator {
    func authenticate(request: HBRequest) -> EventLoopFuture<User?> {
        // check if session exists in redis.
        return request.session.load().flatMap { userId in
            guard let userId = userId else {
                return request.success(nil)
            }
            // find user from userId
            return User.find(userId, on: request.db)
        }
    }
}
