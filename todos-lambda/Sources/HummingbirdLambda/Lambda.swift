import AWSLambdaRuntimeCore
import Hummingbird

/// Protocol for Hummingbird Lambdas. Define the `In` and `Out` types, how you convert from `In` to `HBRequest` and `HBResponse` to `Out`
public protocol HBLambda {
    associatedtype In: Decodable
    associatedtype Out: Encodable
    
    /// Initialize application.
    ///
    /// This is where you add your routes, and setup middleware
    init(_ app: HBApplication)
    
    /// Convert from `In` type to `HBRequest`
    /// - Parameters:
    ///   - context: Lambda context
    ///   - application: Application instance
    ///   - from: input type
    func request(context: Lambda.Context, application: HBApplication, from: In) throws -> HBRequest
    
    /// Convert from `HBResponse` to `Out` type
    /// - Parameter from: response from Hummingbird
    func output(from: HBResponse) -> Out
}
