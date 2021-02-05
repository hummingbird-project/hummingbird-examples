import AWSLambdaRuntime
import Hummingbird
import NIO

/// Specialization of EventLoopLambdaHandler which runs an HBLambda
public struct HBLambdaHandler<L: HBLambda>: EventLoopLambdaHandler {
    public typealias In = L.In
    public typealias Out = L.Out

    public init(context: Lambda.InitializationContext) {
        // create application
        let application = HBApplication(eventLoopGroupProvider: .shared(context.eventLoop))
        application.logger = context.logger
        // add error middleware to catch HBHTTPErrors
        application.middleware.add(LambdaErrorMiddleware())
        // initialize application
        self.lambda = .init(application)
        // store application and responder
        self.application = application
        self.responder = application.constructResponder()
    }
    
    public func shutdown(context: Lambda.ShutdownContext) -> EventLoopFuture<Void> {
        do {
            try self.application.shutdownApplication()
            return context.eventLoop.makeSucceededFuture(())
        } catch {
            return context.eventLoop.makeFailedFuture(error)
        }
    }

    public func handle(context: Lambda.Context, event: L.In) -> EventLoopFuture<L.Out> {
        do {
            let request = try lambda.request(context: context, application: self.application, from: event)
            return self.responder.respond(to: request)
                .map { self.lambda.output(from: $0) }
        } catch {
            return context.eventLoop.makeFailedFuture(error)
        }
    }
    
    let application: HBApplication
    let responder: HBResponder
    let lambda: L
}

