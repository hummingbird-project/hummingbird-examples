import Hummingbird
import Logging

/// Middleware outputting to log for every call to server
public struct ErrorLoggingMiddleware: HBMiddleware {
    let logLevel: Logger.Level

    public init(_ logLevel: Logger.Level = .error) {
        self.logLevel = logLevel
    }

    public func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        return next.respond(to: request)
            .flatMapErrorThrowing { error in
                if error as? HBHTTPResponseError == nil {
                    request.logger.log(level: logLevel, "\(error)")
                }
                throw error
            }
    }
}
