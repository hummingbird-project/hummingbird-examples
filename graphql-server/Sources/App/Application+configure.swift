import Foundation
import Hummingbird
import HummingbirdFoundation
import GraphQL

extension HBApplication {
    public func configure() throws {
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        
        // MARK: - GraphQL Hummingbird Extension
        let graphQLHandler = GraphQLHandler()
        
        // MARK: - Routes
        router.post("/graphql") { request -> GraphQLResult in
            struct GraphQLQuery: Decodable {
                let query: String
                let variables: [String: Map]?
            }
            guard let graphqlQuery = try? request.decode(as: GraphQLQuery.self) else {
                throw GraphQLError(message: "Syntax Error")
            }
            return try await graphQLHandler.handle(
                query: graphqlQuery.query, 
                variables: graphqlQuery.variables, 
                request: request
            )
        }
    }
}
