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

import Hummingbird
import HummingbirdAuth

/// Passes only when the authenticated user's `clearanceLevel` is greater than or
/// equal to the requested document's `classification` (numeric attribute comparison).
///
/// Classification scale: 0 = public, 1 = internal, 2 = confidential, 3 = restricted.
///
/// Because ``DocumentResolverMiddleware`` fetches the document exactly once before
/// any policy runs, this is a pure in-memory numeric comparison — no database
/// calls, no async work, no injected dependencies.
struct SufficientClearancePolicy: AuthorizationPolicy {
    typealias Identity = DocumentRequest

    func isAuthorized(identity: DocumentRequest, request: Request) async throws -> Bool {
        guard let document = identity.document else { return false }
        return identity.user.clearanceLevel >= document.classification
    }
}
