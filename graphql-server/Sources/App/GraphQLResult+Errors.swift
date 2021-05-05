import GraphQL

extension GraphQLResult {
    public static var invalidRequest: GraphQLResult {
        let invalidRequestError = GraphQLError(message: "Invalid request")
        return GraphQLResult(data: nil, errors: [invalidRequestError])
    }
    
    public static var invalidQuery: GraphQLResult {
        let invalidQueryError = GraphQLError(message: "Invalid query")
        return GraphQLResult(data: nil, errors: [invalidQueryError])
    }
}
