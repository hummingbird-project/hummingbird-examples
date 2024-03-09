@testable import App
import Hummingbird
import HummingbirdTesting
import XCTest

final class AppTests: XCTestCase {
    func testGraphQLSuccess() async throws {
        let app = buildApplication(configuration: .init(address: .hostname("127.0.0.1", port: 8080)))
        try await app.test(.router) { client in
            let testQuery = """
            {
                "query": "{hero(episode:NEWHOPE){name}}",
                "variables": {}
            }
            """
            let testBody = ByteBuffer(string: testQuery)
            let expectedResult = #"{"data":{"hero":{"name":"R2-D2"}}}"#
            try await client.execute(
                uri: "/graphql",
                method: .post,
                headers: [.contentType: "application/json; charset=utf-8"],
                body: testBody
            ) { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(String(buffer: res.body).trimmingCharacters(in: .whitespacesAndNewlines), expectedResult)
            }
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
}
