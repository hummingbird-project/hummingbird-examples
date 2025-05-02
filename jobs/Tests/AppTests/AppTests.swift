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
import HummingbirdTesting
import Logging
import XCTest

final class AppTests: XCTestCase {
    struct TestArguments: AppArguments {
        var hostname: String { "127.0.0.1" }
        var port: Int { 0 }
        let processJobs: Bool
        var logLevel: Logger.Level? { .debug }
    }

    func testApp() throws {}
}
