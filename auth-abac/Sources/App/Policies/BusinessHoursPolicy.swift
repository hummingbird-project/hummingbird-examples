//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import Hummingbird
import HummingbirdAuth

/// An environment-attribute policy that passes only during specified hours of the day.
///
/// Uses the server's local calendar and clock — no subject or resource data needed.
/// Generic over `Identity` so it composes freely alongside role and permission policies:
///
/// ```swift
/// // Admin-only deletion, permitted only during business hours
/// .authorized {
///     allOf(RolePolicy(.admin), BusinessHoursPolicy(allowedHours: 9..<17))
/// }
/// ```
///
/// In tests, pass `0..<24` to always allow, or `0..<0` to always deny.
struct BusinessHoursPolicy<Identity: Sendable>: AuthorizationPolicy {
    /// The range of hours (0–23) during which this policy passes.
    let allowedHours: Range<Int>

    init(allowedHours: Range<Int>) {
        self.allowedHours = allowedHours
    }

    func isAuthorized(identity: Identity, request: Request) async throws -> Bool {
        let hour = Calendar(identifier: .gregorian).component(.hour, from: Date())
        return allowedHours.contains(hour)
    }
}
