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

/// The application request context.
///
/// Two-stage identity assembly:
///
/// 1. ``UserAuthenticatorMiddleware`` verifies Basic auth credentials and writes
///    the resolved ``User`` into `authenticatedUser`. The `identity` field remains
///    `nil` at this point.
///
/// 2. Either ``DocumentResolverMiddleware`` (document routes) or
///    ``UserIdentityMiddleware`` (non-document routes) promotes `authenticatedUser`
///    into the full ``DocumentRequest`` identity, fetching the document exactly
///    once where needed.
///
/// All downstream authorization and route handlers operate on `identity`.
struct AppRequestContext: AuthRequestContext, RequestContext {
    typealias Identity = DocumentRequest

    var coreContext: CoreRequestContextStorage

    /// The ``AuthRequestContext`` identity: a fully assembled ``DocumentRequest``.
    /// Set by ``DocumentResolverMiddleware`` or ``UserIdentityMiddleware``.
    var identity: DocumentRequest?

    /// Staging field: the authenticated ``User``, set by ``UserAuthenticatorMiddleware``
    /// before the document (if any) is resolved. Internal to the middleware pipeline.
    var authenticatedUser: User?

    init(source: Source) {
        self.coreContext = .init(source: source)
        self.identity = nil
        self.authenticatedUser = nil
    }
}
