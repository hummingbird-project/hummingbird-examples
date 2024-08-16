//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation

struct Session: Codable {
    enum AuthenticationState: Codable {
        case authenticating(A: String, B: String, serverSharedSecret: String)
        case authenticated
    }

    let userId: UUID
    var state: AuthenticationState
}
