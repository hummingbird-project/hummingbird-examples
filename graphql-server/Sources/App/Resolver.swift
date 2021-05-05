import Graphiti
import NIO

/// https://github.com/GraphQLSwift/Graphiti#defining-the-graphql-api-resolver
/// We’re using the Type as defined by Graphiti above, but this might be refactored into a Hummingbird controller convention
public struct Resolver {
    let group: EventLoopGroup
    func message(context: Context, arguments: NoArguments) -> EventLoopFuture<Message> {
        group.next().makeSucceededFuture(context.message())
    }
}

