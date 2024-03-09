@testable import App
import Hummingbird
import HummingbirdTesting
import XCTest

final class AppTests: XCTestCase {
    func buildQuery(_ query: String, variables: [String: Any] = [:]) throws -> ByteBuffer {
        struct AnyCodable: Encodable {
            let value: Any

            func encode(to encoder: any Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self.value {
                case let string as String:
                    try container.encode(string)
                case let integer as Int:
                    try container.encode(integer)
                default:
                    throw EncodingError.invalidValue(self.value, .init(codingPath: encoder.codingPath, debugDescription: .init("Cannot encode")))
                }
            }
        }
        struct Query: Encodable {
            let query: String
            let variables: [String: Any]

            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(self.query, forKey: .query)
                try container.encode(self.variables.mapValues { AnyCodable(value: $0) }, forKey: .variables)
            }

            private enum CodingKeys: String, CodingKey {
                case query, variables
            }
        }
        let query = Query(query: query, variables: variables)
        return try JSONEncoder().encodeAsByteBuffer(query, allocator: .init())
    }

    func testQuery(
        _ query: String,
        variables: [String: Any] = [:],
        expectedResult: String,
        client: some HBTestClientProtocol,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let testQuery = try self.buildQuery(query, variables: variables)
        try await client.execute(
            uri: "/graphql",
            method: .post,
            headers: [.contentType: "application/json; charset=utf-8"],
            body: testQuery
        ) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(String(buffer: res.body).trimmingCharacters(in: .whitespacesAndNewlines), expectedResult, file: file, line: line)
        }
    }

    struct DataWrapper<Value: Codable>: Codable {
        let data: Value
    }

    func testQuery<Result: Codable & Equatable>(
        _ query: String,
        variables: [String: Any] = [:],
        expectedResult: Result,
        client: some HBTestClientProtocol,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let testQuery = try self.buildQuery(query, variables: variables)
        try await client.execute(
            uri: "/graphql",
            method: .post,
            headers: [.contentType: "application/json; charset=utf-8"],
            body: testQuery
        ) { res in
            XCTAssertEqual(res.status, .ok)
            let result = try JSONDecoder().decode(DataWrapper<Result>.self, from: res.body)
            XCTAssertEqual(result.data, expectedResult, file: file, line: line)
        }
    }

    // MARK: Tests

    func testHeroNewHope() async throws {
        let app = buildApplication(configuration: .init(address: .hostname("127.0.0.1", port: 8080)))
        try await app.test(.router) { client in
            try await self.testQuery(
                "{hero(episode:NEWHOPE){name}}",
                expectedResult: #"{"data":{"hero":{"name":"R2-D2"}}}"#,
                client: client
            )
        }
    }

    func testHeroNameAndFriends() async throws {
        struct Result: Codable, Equatable {
            struct Hero: Codable, Equatable {
                struct Friend: Codable, ExpressibleByStringLiteral, Equatable {
                    let name: String
                    init(stringLiteral string: String) {
                        self.name = string
                    }
                }

                let id: String
                let name: String
                let friends: [Friend]
            }

            let hero: Hero
        }
        let app = buildApplication(configuration: .init(address: .hostname("127.0.0.1", port: 8080)))
        try await app.test(.router) { client in
            try await self.testQuery(
                "query HeroNameAndFriendsQuery{hero{id name friends{name}}}",
                expectedResult: Result(hero: .init(id: "2001", name: "R2-D2", friends: ["Luke Skywalker", "Han Solo", "Leia Organa"])),
                client: client
            )
        }
    }

    func testGraphQLQueryError() async throws {
        let app = buildApplication(configuration: .init(address: .hostname("127.0.0.1", port: 8080)))
        try await app.test(.router) { client in
            let badQuery = #"{ FAIL"#
            let badRequestBody = ByteBuffer(string: badQuery)
            try await client.execute(
                uri: "/graphql",
                method: .post,
                headers: [.contentType: "application/json; charset=utf-8"],
                body: badRequestBody
            ) { res in
                XCTAssertEqual(res.status, .badRequest)
            }
        }
    }

    func testFetchLuke() async throws {
        let app = buildApplication(configuration: .init(address: .hostname("127.0.0.1", port: 8080)))
        try await app.test(.router) { client in
            try await self.testQuery(
                "query FetchLukeQuery{human(id:\"1000\"){name}}",
                expectedResult: #"{"data":{"human":{"name":"Luke Skywalker"}}}"#,
                client: client
            )
        }
    }

    func testFetchSomeID() async throws {
        let app = buildApplication(configuration: .init(address: .hostname("127.0.0.1", port: 8080)))
        try await app.test(.router) { client in
            try await self.testQuery(
                "query FetchSomeIDQuery($someId:String!){human(id:$someId){name}}",
                variables: ["someId": 1002],
                expectedResult: #"{"data":{"human":{"name":"Han Solo"}}}"#,
                client: client
            )
        }
    }

    func testFetchLukeAliased() async throws {
        let app = buildApplication(configuration: .init(address: .hostname("127.0.0.1", port: 8080)))
        try await app.test(.router) { client in
            try await self.testQuery(
                "query FetchLukeAliasedQuery{luke:human(id:\"1000\"){name}}",
                expectedResult: #"{"data":{"luke":{"name":"Luke Skywalker"}}}"#,
                client: client
            )
        }
    }

    func testDuplicateFields() async throws {
        struct Result: Codable, Equatable {
            struct Character: Codable, Equatable {
                struct HomePlanet: Codable, Equatable, ExpressibleByStringLiteral {
                    let name: String
                    init(stringLiteral string: String) {
                        self.name = string
                    }
                }

                let name: String
                let homePlanet: HomePlanet
            }

            let luke: Character
            let leia: Character
        }
        let app = buildApplication(configuration: .init(address: .hostname("127.0.0.1", port: 8080)))
        try await app.test(.router) { client in
            try await self.testQuery(
                "query DuplicateFieldsQuery{luke:human(id:\"1000\"){name homePlanet{name}}leia:human(id:\"1003\"){name homePlanet{name}}}",
                expectedResult: Result(
                    luke: .init(name: "Luke Skywalker", homePlanet: "Tatooine"),
                    leia: .init(name: "Leia Organa", homePlanet: "Alderaan")
                ),
                client: client
            )
        }
    }

    func testUseFragment() async throws {
        struct Result: Codable, Equatable {
            struct Character: Codable, Equatable {
                struct HomePlanet: Codable, Equatable, ExpressibleByStringLiteral {
                    let name: String
                    init(stringLiteral string: String) {
                        self.name = string
                    }
                }

                let name: String
                let homePlanet: HomePlanet
            }

            let luke: Character
            let leia: Character
        }
        let app = buildApplication(configuration: .init(address: .hostname("127.0.0.1", port: 8080)))
        try await app.test(.router) { client in
            try await self.testQuery(
                "query UseFragmentQuery{luke:human(id:\"1000\"){...HumanFragment}leia:human(id:\"1003\"){...HumanFragment}}fragment HumanFragment on Human{name homePlanet{name}}",
                expectedResult: Result(
                    luke: .init(name: "Luke Skywalker", homePlanet: "Tatooine"),
                    leia: .init(name: "Leia Organa", homePlanet: "Alderaan")
                ),
                client: client
            )
        }
    }

    func testTypeOfR2D2() async throws {
        struct Result: Codable, Equatable {
            struct Character: Codable, Equatable {
                let name: String
                let typename: String

                enum CodingKeys: String, CodingKey {
                    case name
                    case typename = "__typename"
                }
            }

            let hero: Character
        }
        let app = buildApplication(configuration: .init(address: .hostname("127.0.0.1", port: 8080)))
        try await app.test(.router) { client in
            try await self.testQuery(
                "query CheckTypeOfR2Query{hero{__typename name}}",
                expectedResult: Result(hero: .init(name: "R2-D2", typename: "Droid")),
                client: client
            )
        }
    }

    func testSearch() async throws {
        struct Result: Codable, Equatable {
            struct SearchResult: Codable, Equatable {
                let name: String
                let primaryFunction: String?
                let diameter: Int?

                init(name: String, primaryFunction: String? = nil, diameter: Int? = nil) {
                    self.name = name
                    self.primaryFunction = primaryFunction
                    self.diameter = diameter
                }
            }

            let search: [SearchResult]
        }
        let app = buildApplication(configuration: .init(address: .hostname("127.0.0.1", port: 8080)))
        try await app.test(.router) { client in
            try await self.testQuery(
                "query{search(query:\"o\"){... on Planet{name diameter}... on Human{name}... on Droid{name primaryFunction}}}",
                expectedResult: Result(search: [
                    .init(name: "Tatooine", diameter: 10465),
                    .init(name: "Han Solo"),
                    .init(name: "Leia Organa"),
                    .init(name: "C-3PO", primaryFunction: "Protocol"),
                ]),
                client: client
            )
        }
    }
}
