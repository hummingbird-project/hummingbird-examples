//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2022-2022 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import App
import Hummingbird
import HummingbirdXCT
import XCTest

final class AppTests: XCTestCase {
    struct TestArguments: AppArguments {
        let processJobs: Bool
    }

    func testApp() throws {
        let app = HBApplication(testing: .live)
        try app.configure(TestArguments(processJobs: true))

        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/send", method: .POST, body: ByteBuffer(string: "Hello")) { response in
            XCTAssertEqual(response.status, .ok)
        }
    }
}
