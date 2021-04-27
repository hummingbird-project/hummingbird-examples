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

import Foundation
import Hummingbird
import HummingbirdMustache

extension HBApplication {
    static func run() -> HBApplication {
        let app = HBApplication(configuration: .init(
            address: .hostname("0.0.0.0", port: 80),
            serverName: "iOSImageServer"
        ))
        do {
            try app.configure()
            try app.start()
        } catch {
            app.logger.error("\(error)")
        }
        return app
    }

    func configure() throws {
        // set application decoder
        self.decoder = RequestDecoder()

        // setup mustache and load templates
        self.mustache = try .init(directory: Bundle.main.bundlePath)
        assert(self.mustache.getTemplate(named: "head") != nil)

        // setup photo library
        self.photoLibrary = PhotoLibraryManager(eventLoop: self.eventLoopGroup.next())

        // add request logging
        self.middleware.add(HBLogRequestsMiddleware(.debug))

        // add login controller routes
        LoginController().addRoutes(to: self.router)

        // setup authenticated router group
        let authenticationMiddleware = AuthenticationMiddleware()
        self.logger.info("Login token is \(authenticationMiddleware.token)")
        self.loginToken = authenticationMiddleware.token
        let authenticatedGroup = router.group().add(middleware: authenticationMiddleware)

        // add image and web controller routes to authenticated router group
        ImageController().addRoutes(to: authenticatedGroup)
        WebController().addRoutes(to: authenticatedGroup)
    }
}

extension HBApplication {
    var photoLibrary: PhotoLibraryManager {
        get { self.extensions.get(\.photoLibrary) }
        set { self.extensions.set(\.photoLibrary, value: newValue) }
    }

    var mustache: HBMustacheLibrary {
        get { self.extensions.get(\.mustache) }
        set { self.extensions.set(\.mustache, value: newValue) }
    }

    var loginToken: String? {
        get { self.extensions.get(\.loginToken) }
        set { self.extensions.set(\.loginToken, value: newValue) }
    }
}
