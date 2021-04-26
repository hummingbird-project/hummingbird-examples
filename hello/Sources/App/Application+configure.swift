import Hummingbird
import HummingbirdFoundation

extension HBApplication {
    /// configure your application
    /// add middleware
    /// setup the encoder/decoder
    /// add your routes
    public func configure() throws {
        middleware.add(HBFileMiddleware(application: self))
        router.get("/") { _ in
            return "Hello"
        }
    }
}
