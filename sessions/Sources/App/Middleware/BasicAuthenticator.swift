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
import HummingbirdFluent
import NIOPosix

struct BasicAuthenticator<Context: AuthRequestContext>: AuthenticatorMiddleware {
    let fluent: Fluent

    func authenticate(request: Request, context: Context) async throws -> LoggedInUser? {
        // does request have basic authentication info in the "Authorization" header
        guard let basic = request.headers.basic else { return nil }

        // check if user exists in the database and then verify the entered password
        // against the one stored in the database. If it is correct then login in user
        let user = try await User.query(on: self.fluent.db())
            .filter(\.$name == basic.username)
            .first()
        guard let user = user else { return nil }
        // Do Bcrypt verify on a separate thread to not block the general task executor 
        guard try await NIOThreadPool.singleton.runIfActive({ Bcrypt.verify(basic.password, hash: user.passwordHash) }) else { return nil }
        return try .init(from: user)
    }
}
