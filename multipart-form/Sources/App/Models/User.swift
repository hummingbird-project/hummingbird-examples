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

import Hummingbird

/// A structure representing a user in the App.
struct User: Decodable {
    /// The name of the user.
    let name: String

    /// The age of the user.
    let age: Int

    /// The profile picture of the user, represented as a `File`.
    let profilePicture: File
}
