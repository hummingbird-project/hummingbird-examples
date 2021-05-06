import Foundation
import Hummingbird
import HummingbirdFoundation
import GraphQL

extension HBApplication {
    public func configure() throws {
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        
        // MARK: - GraphQL Hummingbird Extension
        let graphQLHandler = try GraphQLHandler(group: self.eventLoopGroup)
        extensions.set(\.graphQLHandler, value: graphQLHandler)
        
        // MARK: - Routes
        router.post("/graphql", body: .collate) { request -> EventLoopFuture<GraphQLResult> in
            guard let query = try? request.decode(as: Map.self)
                    .dictionaryValue()["query"] else {
                return request.success(GraphQLResult.invalidRequest)
            }
            switch query {
            case .string(let text):
                return graphQLHandler.handle(query: text)
            default:
                return request.success(GraphQLResult.invalidQuery)
            }
        }
    }
}
