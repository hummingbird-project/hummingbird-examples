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

import Hummingbird
import ServiceLifecycle
import SotoDynamoDB

extension AWSClient: Service {
    public func run() async throws {
        /// Ignore cancellation error
        try? await gracefulShutdown()
        try await self.shutdown()
    }
}
