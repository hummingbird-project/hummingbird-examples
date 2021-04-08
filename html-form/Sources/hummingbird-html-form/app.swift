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

func runApp(_ arguments: HummingbirdArguments) throws {
    let app = HBApplication(configuration: .init(address: .hostname(arguments.hostname, port: arguments.port)))
    app.decoder = RequestDecoder()
    app.mustache = try .init(directory: "templates")
    assert(app.mustache.getTemplate(named: "head") != nil, "Set your working directory to the root folder of this example to get it to work")

    let webController = WebController()
    app.router.get("/", use: webController.input)
    app.router.post("/", use: webController.post)

    app.start()
    app.wait()
}
