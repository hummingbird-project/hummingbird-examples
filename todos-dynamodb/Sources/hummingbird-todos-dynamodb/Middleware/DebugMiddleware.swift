import Hummingbird

struct DebugMiddleware: HBMiddleware {
    func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        request.logger.info("\(request.method) \(request.uri)")
        return next.respond(to: request)
    }
}
