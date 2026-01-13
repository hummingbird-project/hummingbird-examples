import Configuration
import Hummingbird
import HummingbirdTesting
import Logging
import Testing

@testable import App

private let reader = ConfigReader(providers: [
    InMemoryProvider(values: [
        "host": "127.0.0.1",
        "port": "0",
        "log.level": "trace",
    ])
])

struct AppTests {
    @Test func testApp() async throws {
        let app = try await buildApplication(reader: reader)

        try await app.test(.router) { client in
            let urlencoded = "name=Adam&age=34"
            try await client.execute(
                uri: "/",
                method: .post,
                headers: [.contentType: "application/x-www-form-urlencoded"],
                body: ByteBufferAllocator().buffer(string: urlencoded)
            ) { response in
                #expect(response.headers[.contentType] == "text/html")
                #expect(response.status == .ok)
            }
        }
    }
}
