import Foundation
import Hummingbird
import HummingbirdFoundation
import JSONValueRX
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
            guard let json = try? request.decode(as: JSONValue.self),
                  let queryPath: JSONValue = json["query"] else {
                return request.eventLoop.makeSucceededFuture(GraphQLResult.invalidRequest)
            }
            switch queryPath {
            case .string(let text):
                return graphQLHandler.handle(query: text)
            default:
                return request.eventLoop.makeSucceededFuture(GraphQLResult.invalidQuery)
            }
        }
    }
}
