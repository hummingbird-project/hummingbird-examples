import Foundation
import Hummingbird
import HummingbirdFoundation
import GraphQL

extension HBApplication {
    public func configure() throws {
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        
        // MARK: - GraphQL Hummingbird Extension
        self.graphQLHandler = .init()
        
        // MARK: - Routes
        router.post("/graphql", body: .collate) { request -> EventLoopFuture<GraphQLResult> in
            struct GraphQLQuery: Decodable {
                let query: String
                let variables: [String: Map]?
            }
            guard let graphqlQuery = try? request.decode(as: GraphQLQuery.self) else {
                return request.failure(GraphQLError(message: "Syntax Error"))
            }
            return self.graphQLHandler.handle(query: graphqlQuery.query, variables: graphqlQuery.variables, request: request)
        }
    }
}
