//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2025 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HummingbirdAuth
import HummingbirdOIDC

/// The session stores a compact projection of the OIDC identity;
/// the full `OIDCIdentity` is reconstructed in `OIDCSessionAuthenticator`.
typealias AppRequestContext = BasicSessionRequestContext<OIDCSessionData, OIDCIdentity>
