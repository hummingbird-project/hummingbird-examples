//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import App
import Hummingbird
import HummingbirdXCT
import XCTest

final class AppTests: XCTestCase {
    struct TestArguments: AppArguments {}

    func testApp() throws {
        let args = TestArguments()
        let app = HBApplication(testing: .live)
        try app.configure(args)

        try app.XCTStart()
        defer { XCTAssertNoThrow(app.XCTStop()) }

        try app.XCTExecute(uri: "/health", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
        }
    }
}
