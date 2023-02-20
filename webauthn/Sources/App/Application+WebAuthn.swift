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

import Hummingbird
import WebAuthn

extension HBApplication {
    var webauthn: WebAuthnManager {
        get { self.extensions.get(\.webauthn) }
        set { self.extensions.set(\.webauthn, value: newValue) }
    }
}
