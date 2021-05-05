import NIO
import Graphiti
import GraphQL

public struct GraphQLHandler {
    let context = Context()
    let api: GraphQLAPI
    let group: EventLoopGroup
    
    init(group: EventLoopGroup) throws {
        self.group = group
        let resolver = Resolver(group: group)
        self.api = try GraphQLAPI(resolver: resolver)
    }
    
    /// Executes queries
    /// - Parameter query: a String with a valid GraphQL query. Like `{ message { context }}`
    /// - Returns: `EventLoopFuture<GraphQLResult>` which might contain results or be a failure
    /// Note that Graphiti fails internally on invalid queries like `{ FAIL` returning a `500 Internal Server Error`
    func handle(query: String) -> EventLoopFuture<GraphQLResult> {
        api.execute(request: query, context: context, on: group)
    }
}
