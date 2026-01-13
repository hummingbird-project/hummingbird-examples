import Hummingbird
import HummingbirdTesting
import ServiceLifecycle
import Testing

@testable import App

struct AppTests {
    struct TestAppArguments: AppArguments {
        var hostname: String { "127.0.0.1" }
        var port: Int { 8081 }
        var location: String
        var target: String
    }

    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func testProxy(
        setupRouter: @escaping (Router<BasicRequestContext>) -> Void,
        test: @escaping @Sendable (Int) async throws -> Void
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            let (stream, source) = AsyncStream.makeStream(of: Int.self)
            // Setup server to proxy, need to run it inside a ServiceGroup so we can
            // trigger graceful shutdown at the end
            let router = Router()
            setupRouter(router)
            let app = Application(
                router: router,
                configuration: .init(address: .hostname(port: 0)),
                onServerRunning: { channel in source.yield(channel.localAddress!.port!) }
            )
            let serviceGroup = ServiceGroup(
                configuration: .init(
                    services: [app],
                    gracefulShutdownSignals: [.sigterm, .sigint],
                    logger: app.logger
                )
            )
            group.addTask {
                // Run Server service group
                try await serviceGroup.run()
            }
            // wait until server port is available
            let port = await stream.first { _ in true }
            app.logger.info("Proxy point to http://localhost:\(port!)")
            // run test
            try await test(port!)
            await serviceGroup.triggerGracefulShutdown()
        }
    }

    // MARK: tests

    @Test func testSimple() async throws {
        try await self.testProxy { router in
            router.get("hello") { _, _ in
                "Hello"
            }
        } test: { port in
            let proxy = buildApplication(TestAppArguments(location: "", target: "http://localhost:\(port)"))
            try await proxy.test(.live) { client in
                try await client.execute(uri: "/hello", method: .get) { response in
                    #expect(String(buffer: response.body) == "Hello")
                }
            }
        }
    }

    @Test func testLocation() async throws {
        try await self.testProxy { router in
            router.get("hello") { _, _ in
                "Hello"
            }
        } test: { port in
            let proxy = buildApplication(TestAppArguments(location: "/proxy", target: "http://localhost:\(port)"))
            try await proxy.test(.live) { client in
                try await client.execute(uri: "/proxy/hello", method: .get) { response in
                    #expect(String(buffer: response.body) == "Hello")
                }
            }
        }
    }

    @Test func testEchoBody() async throws {
        let string = "This is a test body"
        let buffer = ByteBuffer(string: string)
        try await self.testProxy { router in
            router.post("echo") { request, _ in
                // test content length was passed through
                #expect(request.headers[.contentLength] == buffer.readableBytes.description)
                return Response(status: .ok, body: .init(asyncSequence: request.body))
            }
        } test: { port in
            let proxy = buildApplication(TestAppArguments(location: "", target: "http://localhost:\(port)"))
            try await proxy.test(.live) { client in
                try await client.execute(uri: "/echo", method: .post, body: buffer) { response in
                    #expect(response.body == buffer)
                }
            }
        }
    }

    @Test func testLargeBody() async throws {
        try await self.testProxy { router in
            router.post("echo") { request, _ in
                Response(status: .ok, body: .init(asyncSequence: request.body))
            }
        } test: { port in
            let proxy = buildApplication(TestAppArguments(location: "", target: "http://localhost:\(port)"))
            try await proxy.test(.live) { client in
                let buffer = self.randomBuffer(size: 1024 * 1500)
                try await client.execute(uri: "/echo", method: .post, body: buffer) { response in
                    #expect(response.body == buffer)
                }
            }
        }
    }
}
