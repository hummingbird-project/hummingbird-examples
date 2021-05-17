import Graphiti
import NIO

extension Character {
    public var secretBackstory: String? {
        nil
    }
    
    public func getFriends(context: StarWarsContext, arguments: NoArguments) -> [Character] {
        []
    }
}

extension Human {
    public func getFriends(context: StarWarsContext, arguments: NoArguments) -> EventLoopFuture<[Character]> {
        context.getFriends(of: self)
    }
    
    public func getSecretBackstory(context: StarWarsContext, arguments: NoArguments) -> EventLoopFuture<String?> {
        context.getSecretBackStory()
    }
}

/**
 * StarWars API Example
 * Graphiti
 * This example comes from the [Graphiti StarWarsAPI](https://github.com/GraphQLSwift/Graphiti/tree/master/Tests/GraphitiTests/StarWarsAPI) example
 *
 * The Graphiti [README](https://github.com/GraphQLSwift/Graphiti#getting-started) is also a helpful reference.
 */
extension Droid {
    public func getFriends(context: StarWarsContext, arguments: NoArguments) -> EventLoopFuture<[Character]> {
        context.getFriends(of: self)
    }
    
    public func getSecretBackstory(context: StarWarsContext, arguments: NoArguments) -> EventLoopFuture<String?> {
        context.getSecretBackStory()
    }
}

public struct StarWarsResolver {
    public init() {}
    
    public struct HeroArguments : Codable {
        public let episode: Episode?
    }

    public func hero(context: StarWarsContext, arguments: HeroArguments) -> EventLoopFuture<Character> {
        context.getHero(of: arguments.episode)
    }

    public struct HumanArguments : Codable {
        public let id: String
    }
    
    public func human(context: StarWarsContext, arguments: HumanArguments) -> EventLoopFuture<Human?> {
        context.getHuman(id: arguments.id)
    }

    public struct DroidArguments : Codable {
        public let id: String
    }

    public func droid(context: StarWarsContext, arguments: DroidArguments) -> EventLoopFuture<Droid?> {
        context.getDroid(id: arguments.id)
    }
    
    public struct SearchArguments : Codable {
        public let query: String
    }
    
    public func search(context: StarWarsContext, arguments: SearchArguments) -> EventLoopFuture<[SearchResult]> {
        context.search(query: arguments.query)
    }
}
