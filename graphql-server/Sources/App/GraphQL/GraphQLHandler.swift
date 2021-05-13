import NIO
import Graphiti
import GraphQL

// https://github.com/GraphQLSwift/Graphiti#querying
public struct GraphQLHandler {
    let context = StarWarsContext()
    let api = StarWarsAPI()
    let group: EventLoopGroup
    
    init(group: EventLoopGroup) throws {
        self.group = group
    }
    
    /// Executes queries
    /// - Parameter query: a String with a valid GraphQL query. Like `{ message { context }}`
    /// - Returns: `EventLoopFuture<GraphQLResult>` which might contain results or be a failure
    /// Note that Graphiti fails internally on invalid queries like `{ FAIL` returning a `500 Internal Server Error`
    func handle(query: String) -> EventLoopFuture<GraphQLResult> {
        api.execute(request: query, context: context, on: group)
    }
}
