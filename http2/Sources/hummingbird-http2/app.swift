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
import HummingbirdHTTP2

struct App {
    let arguments: AppArguments

    func run() throws {
        let app = HBApplication(configuration: .init(address: .hostname(arguments.hostname, port: self.arguments.port)))
        // Add HTTP2 TLS Upgrade option
        try app.server.addHTTP2Upgrade(tlsConfiguration: self.getTLSConfig())

        app.router.get("/http") { request in
            return "Using http v\(request.version.major).\(request.version.minor)"
        }
        app.start()
        app.wait()
    }

    func getTLSConfig() throws -> TLSConfiguration {
        let certificateChain = try NIOSSLCertificate.fromPEMFile(self.arguments.certificateChain)
        let privateKey = try NIOSSLPrivateKey(file: arguments.privateKey, format: .pem)
        return TLSConfiguration.forServer(certificateChain: certificateChain.map { .certificate($0) }, privateKey: .privateKey(privateKey))
    }
}
