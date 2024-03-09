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
    struct TestArguments: AppArguments {
        var hostname: String { "127.0.0.1" }
        var port: Int { 8080 }
        var inMemoryDatabase: Bool { true }
        var privateKey: String { "certs/server.key" }
        var certificateChain: String { "certs/server.crt" }
    }

    func testApp() async throws {
        let args = TestArguments()
        let app = try await buildApplication(args)
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/health", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }
}
