import Hummingbird
import HummingbirdXCT
import XCTest
import hummingbird_testing

final class HummingbirdTests: XCTestCase {
    static var allTests = [
        ("testHealthCheck", testHealthCheck),
    ]
    var app: HBApplication!
    
    override func setUpWithError() throws {
        app = HBApplication(testing: .live)
        try Boot.configureRoutes(&app)
        app.XCTStart()
    }
    
    override func tearDownWithError() throws {
        app.XCTStop()
    }
    
    func testHealthCheck() throws {
        app.XCTExecute(uri: "/healthcheck", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
            
            guard let bytes = response.body else {
                XCTFail("Response body had no readable bytes")
                return
            }
            
            let body = String(buffer: bytes)
            XCTAssertEqual(body, "OK")
        }
    }
}
