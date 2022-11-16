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

import FluentKit
import Foundation
import Hummingbird
import HummingbirdAuth

struct SessionAuthenticator: HBAsyncSessionAuthenticator {
    typealias Session = UUID
    typealias Value = User

    func getValue(from: UUID, request: Hummingbird.HBRequest) async throws -> User? {
            // find user from userId
            return try await User.find(from, on: request.db)
    }
}
