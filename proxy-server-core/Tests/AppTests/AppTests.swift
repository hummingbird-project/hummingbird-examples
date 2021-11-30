import App
import AsyncHTTPClient
import HummingbirdCore
import HummingbirdCoreXCT
import Logging
import NIOCore
import NIOHTTP1
import NIOPosix
import XCTest

final class AppTests: XCTestCase {
    static var eventLoopGroup: EventLoopGroup!
    static var httpClient: HTTPClient!
    static var logger = Logger(label: "ProxyTests")

    static override func setUp() {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
    }

    static override func tearDown() {
        XCTAssertNoThrow(try httpClient.syncShutdown())
        XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
    }

    func startTargetServer(_ responder: HBHTTPResponder) throws -> HBHTTPServer {
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 0)))
        try server.start(responder: responder).wait()
        return server
    }

    func startProxyServer(port: Int) throws -> HBHTTPServer {
        let responder = HTTPProxyServer(
            targetServer: "http://localhost:\(port)",
            httpClient: Self.httpClient,
            logger: Self.logger
        )
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 0)))
        try server.start(responder: responder).wait()
        return server
    }

    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func testSimple() throws {
        struct HelloResponder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok)
                let responseBody = context.channel.allocator.buffer(string: "Hello")
                let response = HBHTTPResponse(head: responseHead, body: .byteBuffer(responseBody))
                onComplete(.success(response))
            }
        }

        let server = try startTargetServer(HelloResponder())
        defer { XCTAssertNoThrow(try server.stop().wait()) }
        let proxy = try startProxyServer(port: server.port!)
        defer { XCTAssertNoThrow(try proxy.stop().wait()) }

        let client = HBXCTClient(host: "localhost", port: proxy.port!, eventLoopGroupProvider: .createNew)
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let future = client.get("/").flatMapThrowing { response in
            var body = try XCTUnwrap(response.body)
            XCTAssertEqual(body.readString(length: body.readableBytes), "Hello")
        }
        XCTAssertNoThrow(try future.wait())

    }

    func testEchoBody() throws {
        struct EchoBodyResponder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok)
                let response = HBHTTPResponse(head: responseHead, body: .stream(request.body.stream!))
                onComplete(.success(response))
            }
        }

        let server = try startTargetServer(EchoBodyResponder())
        defer { XCTAssertNoThrow(try server.stop().wait()) }
        let proxy = try startProxyServer(port: server.port!)
        defer { XCTAssertNoThrow(try proxy.stop().wait()) }

        let client = HBXCTClient(host: "localhost", port: proxy.port!, eventLoopGroupProvider: .createNew)
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let future = client.post("/", body: ByteBuffer(string: "Hello")).flatMapThrowing { response in
            var body = try XCTUnwrap(response.body)
            XCTAssertEqual(body.readString(length: body.readableBytes), "Hello")
        }
        XCTAssertNoThrow(try future.wait())

    }

    func testLargeBody() throws {
        struct EchoBodyResponder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok)
                let response = HBHTTPResponse(head: responseHead, body: .stream(request.body.stream!))
                onComplete(.success(response))
            }
        }

        let server = try startTargetServer(EchoBodyResponder())
        defer { XCTAssertNoThrow(try server.stop().wait()) }
        let proxy = try startProxyServer(port: server.port!)
        defer { XCTAssertNoThrow(try proxy.stop().wait()) }

        let client = HBXCTClient(host: "localhost", port: proxy.port!, eventLoopGroupProvider: .createNew)
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let buffer = randomBuffer(size: 1024 * 1500)
        let future = client.post("/", body: buffer).flatMapThrowing { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(body, buffer)
        }
        XCTAssertNoThrow(try future.wait())

    }
}
