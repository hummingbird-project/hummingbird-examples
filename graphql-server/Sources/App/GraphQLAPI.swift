import Graphiti

public struct GraphQLAPI: API {
    public let resolver: Resolver
    public let schema: Schema<Resolver, Context>
    
    init(resolver: Resolver) throws {
        self.resolver = resolver
        self.schema = try Schema<Resolver, Context> {
            Type(Message.self) {
                Field("content", at: \.content)
            }
            Query {
                Field("message", at: Resolver.message)
            }
        }
    }
}
