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
import HummingbirdFluent

/// Session authentication. Get UUID attached to session id in request and return
/// the associated user
struct SessionAuthenticator<Context: HBAuthRequestContextProtocol>: HBSessionAuthenticator {
    typealias Session = UUID
    typealias Value = User

    let fluent: HBFluent
    let sessionStorage: HBSessionStorage

    func getValue(from: UUID, request: Hummingbird.HBRequest, context: Context) async throws -> User? {
        // find user from userId
        return try await User.find(from, on: self.fluent.db())
    }
}
