/**
 * StarWars API Example
 * Graphiti
 * This example comes from the [Graphiti StarWarsAPI](https://github.com/GraphQLSwift/Graphiti/tree/main/Tests/GraphitiTests/StarWarsAPI) example
 *
 * The Graphiti [README](https://github.com/GraphQLSwift/Graphiti#getting-started) is also a helpful reference.
 */
public enum Episode: String, Codable, CaseIterable {
    case newHope = "NEWHOPE"
    case empire = "EMPIRE"
    case jedi = "JEDI"
}

public protocol Character: Codable {
    var id: String { get }
    var name: String { get }
    var friends: [String] { get }
    var appearsIn: [Episode] { get }
}

public protocol SearchResult: Codable {}

public struct Planet: SearchResult, Codable {
    public let id: String
    public let name: String
    public let diameter: Int
    public let rotationPeriod: Int
    public let orbitalPeriod: Int
    public var residents: [Human]
}

public struct Human: Character, SearchResult, Codable {
    public let id: String
    public let name: String
    public let friends: [String]
    public let appearsIn: [Episode]
    public let homePlanet: Planet
}

public struct Droid: Character, SearchResult, Codable {
    public let id: String
    public let name: String
    public let friends: [String]
    public let appearsIn: [Episode]
    public let primaryFunction: String
}
