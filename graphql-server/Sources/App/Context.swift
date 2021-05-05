/// https://github.com/GraphQLSwift/Graphiti#defining-the-context
/// We’re using the Type defined by Graphiti documenatation (above).
/// “This is the place where you can put code that talks to a database or another service.”
public struct Context {
    func message() -> Message {
        Message(content: "Hello, world!")
    }
}

