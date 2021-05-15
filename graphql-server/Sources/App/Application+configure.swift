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
            guard let query = try? request.decode(as: Map.self)
                    .dictionaryValue()["query"] else {
                return request.failure(GraphQLError(message: "Syntax Error"))
            }
            switch query {
            case .string(let text):
                return self.graphQLHandler.handle(query: text, request: request)
            default:
                return request.failure(GraphQLError(message: "Invalid Request"))
            }
        }
    }
}
