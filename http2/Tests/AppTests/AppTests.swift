@testable import App
import Hummingbird
import HummingbirdXCT
import HBXCTAsyncHTTPClient
import NIOSSL
import XCTest

struct TestAppArguments: AppArguments {
    var certificateChain = "certs/server.crt"
    var privateKey = "certs/server.key"
}

final class AppTests: XCTestCase {
    func testApp() throws {
        var clientConfiguration = TLSConfiguration.makeClientConfiguration();
        clientConfiguration.certificateVerification = .none
        let app = HBApplication(
            testing: .ahc(scheme: .https),
            configuration: .init(idleTimeoutConfiguration: .init(readTimeout: .seconds(5), writeTimeout: .seconds(5))),
            clientConfiguration: .init(tlsConfiguration: clientConfiguration)
        )
        try app.configure(TestAppArguments())

        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/http", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.body.map { String(buffer: $0) }, "Using http v2.0")
        }

        try app.XCTExecute(uri: "/http", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.body.map { String(buffer: $0) }, "Using http v2.0")
        }
    }
}
