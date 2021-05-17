import NIO
import Graphiti
import GraphQL
import Hummingbird

// https://github.com/GraphQLSwift/Graphiti#querying
public struct GraphQLHandler {
    let api = StarWarsAPI()

    /// Executes queries
    /// - Parameter query: a String with a valid GraphQL query. Like `{ message { context }}`
    /// - Returns: `EventLoopFuture<GraphQLResult>` which might contain results or be a failure
    /// Note that Graphiti fails internally on invalid queries like `{ FAIL` returning a `500 Internal Server Error`
    func handle(query: String, variables: [String: Map]?, request: HBRequest) -> EventLoopFuture<GraphQLResult> {
        let context = StarWarsContext(request: request)
        return api.execute(request: query, context: context, on: request.eventLoop, variables: variables ?? [:])
    }
}
