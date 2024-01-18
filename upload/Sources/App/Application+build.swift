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
import HummingbirdFoundation
import Logging
import NIOCore

struct UploadRequestContext: HBRequestContext {
    var coreContext: HBCoreRequestContext
    var requestDecoder: JSONDecoder { .init() }
    var responseEncoder: JSONEncoder { .init() }

    init(allocator: ByteBufferAllocator, logger: Logger) {
        self.coreContext = .init(
            allocator: allocator,
            logger: logger
        )
    }
}

func buildApplication(args: AppArguments) -> some HBApplicationProtocol {
    let router = HBRouter(context: UploadRequestContext.self)
    FileController().addRoutes(to: router.group("files"))
    return HBApplication(router: router)
}
