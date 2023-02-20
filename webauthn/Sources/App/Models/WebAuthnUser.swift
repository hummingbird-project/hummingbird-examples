//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import WebAuthn

/// Protocol to interact with a user throughout the registration ceremony
struct HBWebAuthnUser: User {
    /// A unique identifier for the user. For privacy reasons it should NOT be something like an email address.
    let userID: String
    /// A value that will help the user identify which account this credential is associated with.
    /// Can be an email address, etc...
    let name: String
    /// A user-friendly representation of their account. Can be a full name ,etc...
    let displayName: String
}
