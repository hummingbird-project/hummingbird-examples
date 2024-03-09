import Graphiti
import GraphQL
import Hummingbird
import NIO

// https://github.com/GraphQLSwift/Graphiti#querying
public struct GraphQLHandler {
    let api = StarWarsAPI()

    /// Executes queries
    /// - Parameter query: a String with a valid GraphQL query. Like `{ message { context }}`
    /// - Returns: `EventLoopFuture<GraphQLResult>` which might contain results or be a failure
    /// Note that Graphiti fails internally on invalid queries like `{ FAIL` returning a `500 Internal Server Error`
    func handle(query: String, variables: [String: Map]?, eventLoop: EventLoop) async throws -> GraphQLResult {
        let starWarsContext = StarWarsContext()
        return try await self.api.execute(request: query, context: starWarsContext, on: eventLoop, variables: variables ?? [:])
    }
}
