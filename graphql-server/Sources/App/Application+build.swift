import Foundation
import GraphQL
import Hummingbird
import NIOPosix

func buildApplication(configuration: HBApplicationConfiguration) -> some HBApplicationProtocol {
    let graphQLHandler = GraphQLHandler()
    let eventLoopGroup = MultiThreadedEventLoopGroup.singleton

    let router = HBRouter()
    router.post("/graphql") { request, context -> GraphQLResult in
        struct GraphQLQuery: Decodable {
            let query: String
            let variables: [String: Map]?
        }
        guard let graphqlQuery = try? await request.decode(as: GraphQLQuery.self, context: context) else {
            throw GraphQLError(message: "Syntax Error")
        }
        return try await graphQLHandler.handle(
            query: graphqlQuery.query,
            variables: graphqlQuery.variables,
            eventLoop: eventLoopGroup.any()
        )
    }

    let app = HBApplication(
        router: router,
        configuration: configuration,
        eventLoopGroupProvider: .shared(eventLoopGroup)
    )
    return app
}
