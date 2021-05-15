import Hummingbird

extension HBApplication {
    /// Create an HBApplication extension for storing our GraphQLHandler
    public var graphQLHandler: GraphQLHandler {
        get { self.extensions.get(\.graphQLHandler) }
        set { self.extensions.set(\.graphQLHandler, value: newValue) }
    }
}
