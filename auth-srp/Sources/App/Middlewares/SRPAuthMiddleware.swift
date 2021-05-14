import Hummingbird
import HummingbirdAuth

struct SRPAuthMiddleware: HBMiddleware {
    func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        return next.respond(to: request)
    }
}
