import FluentKit
import Hummingbird
import HummingbirdAuth

struct BasicAuthenticator: HBAuthenticator {
    func authenticate(request: HBRequest) -> EventLoopFuture<Void> {
        guard let basic = request.auth.basic else { return request.success(()) }
        
        return User.query(on: request.db)
            .filter(\.$name == basic.username)
            .first()
            .map { user -> Void in
                guard let user = user else { return }
                if Bcrypt.verify(basic.password, hash: user.passwordHash) {
                    request.auth.login(user)
                }
            }
            .hop(to: request.eventLoop)
    }
    
    
}
