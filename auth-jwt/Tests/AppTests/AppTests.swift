import App
import Hummingbird
import HummingbirdXCT
import XCTest

final class AppTests: XCTestCase {
  func testApp() throws {
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
