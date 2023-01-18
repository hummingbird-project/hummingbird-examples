import App
import Hummingbird
import HummingbirdXCT
import XCTest

final class AppTests: XCTestCase {
    func testGraphQLSuccess() throws {
        let app = HBApplication(testing: .live)
        try app.configure()

        try app.XCTStart()
        defer { app.XCTStop() }

        let testQuery = """
        {
            "query": "{hero(episode:NEWHOPE){name}}",
            "variables": {}
        }
        """
        let testBody = ByteBuffer(string: testQuery)
        let expectedResult = #"{"data":{"hero":{"name":"R2-D2"}}}"#
        try app.XCTExecute(
            uri: "/graphql",
            method: .POST,
            headers: .init(dictionaryLiteral: ("Content-Type", "application/json; charset=utf-8")),
            body: testBody
        ) { res in
            XCTAssertEqual(res.status, .ok)

            let body = try XCTUnwrap(res.body)

            let testBodyString = body.getString(at: 0, length: body.capacity)?.trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertEqual(testBodyString, expectedResult)
        }
    }

    func testGraphQLQueryError() throws {
        let app = HBApplication(testing: .live)
        try app.configure()

        try app.XCTStart()
        defer { app.XCTStop() }

        let badQuery = #"{ FAIL"#
        let badRequestBody = ByteBuffer(string: badQuery)
        try app.XCTExecute(
            uri: "/graphql",
            method: .POST,
            headers: .init(dictionaryLiteral: ("Content-Type", "application/json; charset=utf-8")),
            body: badRequestBody
        ) { res in
            XCTAssertEqual(res.status, .badRequest)
        }
    }
}
