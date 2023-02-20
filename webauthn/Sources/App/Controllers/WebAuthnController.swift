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
import HummingbirdAuth
import WebAuthn

struct HBWebAuthnController {
    init(_: HBRouterGroup) {}

    struct BeginRegistrationHandler: HBAsyncRouteHandler {
        struct Input: Decodable {
            let userID: String
            let displayName: String
        }

        typealias Output = PublicKeyCredentialCreationOptions

        let input: Input

        init(from request: Hummingbird.HBRequest) throws {
            self.input = try request.decode(as: Input.self)
        }

        func handle(request: Hummingbird.HBRequest) async throws -> Output {
            let webAuthnUser = HBWebAuthnUser(
                userID: input.userID,
                name: "Hummingbird Authn Example",
                displayName: self.input.displayName
            )
            let options = try request.webauthn.beginRegistration(user: webAuthnUser)
            // req.session.data["challenge"] = options.challenge
            return options
        }
    }
    /* func beginRegistration(request: HBRequest) -> PublicKeyCredentialCreationOptions {
         let user = try request.authRequire(User.self)
         let options = try request.webAuthn.beginRegistration(user: user)
         request.session.
             // req.session.data["challenge"] = options.challenge
             return options
     }

      authSessionRoutes.post("makeCredential") { req -> HTTPStatus in
          let user = try req.auth.require(User.self)
          guard let challenge = req.session.data["challenge"] else { throw Abort(.unauthorized) }
          let registrationCredential = try req.content.decode(RegistrationCredential.self)

          let credential = try await req.webAuthn.finishRegistration(
              challenge: challenge,
              credentialCreationData: registrationCredential,
              // this is likely to be removed soon
              confirmCredentialIDNotRegisteredYet: { credentialID in
                  try await queryCredentialWithUser(id: credentialID) == nil
              }
          )

          try await WebAuthnCredential(from: credential, userID: user.requireID())
              .save(on: req.db)

          return .ok
      } */
}
