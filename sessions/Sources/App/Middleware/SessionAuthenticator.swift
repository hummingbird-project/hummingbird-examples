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

struct SessionAuthenticator<Context: HBAuthRequestContextProtocol>: HBSessionAuthenticator {
    typealias Session = UUID
    typealias Value = LoggedInUser

    let sessionStorage: HBSessionStorage
    let fluent: HBFluent

    func getValue(from: UUID, request: HBRequest, context: Context) async throws -> Value? {
        // find user from userId
        guard let user = try await User.find(from, on: self.fluent.db()) else { return nil }
        return try .init(from: user)
    }

    func getSession(request: HBRequest, context: Context) async throws -> Session? {
        try await self.sessionStorage.load(request: request)
    }
}
