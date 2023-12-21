@testable import App
import Hummingbird
import HummingbirdXCT
import XCTest

final class AppTests: XCTestCase {
    func testCreate() async throws {
        try XCTSkipIf(HBEnvironment().get("CI") != nil)

        let app = buildApplication(configuration: .init())
        try await app.test(.live) { client in
            let todo = try await client.XCTExecute(
                uri: "/todos",
                method: .post,
                body: ByteBufferAllocator().buffer(string: #"{"title":"add more tests"}"#)
            ) { response in
                XCTAssertEqual(response.status, .created)
                let body = try XCTUnwrap(response.body)
                return try JSONDecoder().decode(Todo.self, from: body)
            }
            let todoId = try XCTUnwrap(todo.id)
            try await client.XCTExecute(
                uri: "/todos/\(todoId)",
                method: .get
            ) { response in
                XCTAssertEqual(response.status, .ok)
                let body = try XCTUnwrap(response.body)
                let todo = try JSONDecoder().decode(Todo.self, from: body)
                XCTAssertEqual(todo.id, todoId)
                XCTAssertEqual(todo.title, "add more tests")
            }
        }
    }

    func testList() async throws {
        try XCTSkipIf(HBEnvironment().get("CI") != nil)

        let app = buildApplication(configuration: .init())
        try await app.test(.live) { client in
            let todo = try await client.XCTExecute(
                uri: "/todos",
                method: .post,
                body: ByteBufferAllocator().buffer(string: #"{"title":"add more tests"}"#)
            ) { response in
                XCTAssertEqual(response.status, .created)
                let body = try XCTUnwrap(response.body)
                return try JSONDecoder().decode(Todo.self, from: body)
            }
            let todoId = try XCTUnwrap(todo.id)
            try await client.XCTExecute(
                uri: "/todos/",
                method: .get
            ) { response in
                XCTAssertEqual(response.status, .ok)
                let body = try XCTUnwrap(response.body)
                let todos = try JSONDecoder().decode([Todo].self, from: body)
                let todo = try XCTUnwrap(todos.first { $0.id == todoId })
                XCTAssertEqual(todo.id, todoId)
                XCTAssertEqual(todo.title, "add more tests")
            }
        }
    }
}
