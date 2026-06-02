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

/// Passes only when the authenticated user's `department` matches the requested
/// document's `department` (subject-attribute vs. resource-attribute comparison).
///
/// Because ``DocumentResolverMiddleware`` fetches the document exactly once before
/// any policy runs, this check is a pure in-memory property comparison — no
/// database calls, no async work, no injected dependencies.
///
/// Combine with ``SufficientClearancePolicy`` for the full read-access policy:
///
/// ```swift
/// .add(middleware: AuthorizationPolicyMiddleware(
///     anyOf(
///         RolePolicy(.admin),
///         allOf(SameDepartmentPolicy(), SufficientClearancePolicy())
///     )
/// ))
/// ```
struct SameDepartmentPolicy: AuthorizationPolicy {
    typealias Identity = DocumentRequest

    func isAuthorized(identity: DocumentRequest, request: Request) async throws -> Bool {
        guard let document = identity.document else { return false }
        return identity.user.department == document.department
    }
}
