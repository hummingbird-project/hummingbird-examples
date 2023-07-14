import App
import Foundation
import Hummingbird
import HummingbirdXCT
import XCTest

final class AppTests: XCTestCase {
  let jwksURL = ProcessInfo.processInfo.environment["JWKS_URL"]

  func testApp() throws {
    try XCTSkipIf(self.jwksURL == nil, "Skipping test because jwksURL environment variable not set")
    let app = HBApplication(testing: .live)
    try app.configure()

    try app.XCTStart()
    defer { app.XCTStop() }

    try app.XCTExecute(uri: "/", method: .GET) { response in
      XCTAssertEqual(response.status, .ok)
      XCTAssertEqual(response.body.map { String(buffer: $0) }, "Hello")
    }
  }
}
