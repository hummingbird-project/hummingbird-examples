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
import Hummingbird
import HummingbirdAuth

struct BasicAuthenticator: HBAuthenticator {
    func authenticate(request: HBRequest) -> EventLoopFuture<User?> {
        // does request have basic authentication info in the "Authorization" header
        guard let basic = request.auth.basic else { return request.success(nil) }

        // check if user exists in the database and then verify the entered password
        // against the one stored in the database. If it is correct then login in user
        return User.query(on: request.db)
            .filter(\.$name == basic.username)
            .first()
            .map { user -> User? in
                guard let user = user else { return nil }
                if Bcrypt.verify(basic.password, hash: user.passwordHash) {
                    return user
                }
                return nil
            }
            // hop back to request eventloop
            .hop(to: request.eventLoop)
    }
}
