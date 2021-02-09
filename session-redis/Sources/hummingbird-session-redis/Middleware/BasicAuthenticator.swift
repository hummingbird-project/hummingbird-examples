import FluentKit
import Hummingbird
import HummingbirdAuth

struct BasicAuthenticator: HBAuthenticator {
    func authenticate(request: HBRequest) -> EventLoopFuture<Void> {
        // does request have basic authentication info in the "Authorization" header
        guard let basic = request.auth.basic else { return request.success(()) }

        // check if user exists in the database and then verify the entered password
        // against the one stored in the database. If it is correct then login in user
        return User.query(on: request.db)
            .filter(\.$name == basic.username)
            .first()
            .map { user -> Void in
                guard let user = user else { return }
                if Bcrypt.verify(basic.password, hash: user.passwordHash) {
                    request.auth.login(user)
                }
            }
            // hop back to request eventloop
            .hop(to: request.eventLoop)
    }
}
