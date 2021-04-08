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
import Foundation
import Hummingbird
import HummingbirdAuth

struct SessionAuthenticator: HBAuthenticator {
    func authenticate(request: HBRequest) -> EventLoopFuture<User?> {
        return request.session.load()
            // hop back to request eventloop
            .hop(to: request.eventLoop)
    }

    /// Add repeating task to cleanup expired session entries
    static func scheduleTidyUp(application: HBApplication) {
        let eventLoop = application.eventLoopGroup.next()
        eventLoop.scheduleRepeatedAsyncTask(initialDelay: .seconds(1), delay: .hours(1)) { _ in
            return SessionData.query(on: application.db)
                .filter(\.$expires < Date())
                .delete()
        }
    }
}
