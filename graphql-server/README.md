# GraphQL Server 

This example recreates the GraphQLSwift [Graphiti getting started guide](https://github.com/GraphQLSwift/Graphiti#getting-started) using Hummingbird as the server framework.


## Ideas to extend use

- Replace the `Context` with `Fluent` or another persistance/query layer
- Sanitize the query `String` before handling the query
- Change the behavior of `GraphQLHandler` to more gracefully handle failed queries. Unlike now where it returns a 500 Internal Server Error
