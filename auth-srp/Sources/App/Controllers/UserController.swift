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

import Crypto
import ExtrasBase64
import FluentKit
import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent
import NIO
import SRP

struct UserController {
    typealias Context = AppRequestContext

    let srp = SRPServer<Insecure.SHA1>(configuration: .init(.N2048))
    let fluent: Fluent

    /// Return routes
    var routes: RouteCollection<Context> {
        let routes = RouteCollection(context: Context.self)
        routes.post(use: self.createUser)
        routes.post("login", use: self.initLogin)
        routes.post("verify", use: self.verifyLogin)
        routes.group()
            .add(
                middleware: SessionAuthenticator { (session: SRPSession, context) -> User? in
                    switch session.state {
                    case .authenticated:
                        return try await User.find(session.userID, on: self.fluent.db())
                    case .authenticating:
                        return nil
                    }
                }
            )
            .get("loggedIn.html", use: self.loggedIn)
        return routes
    }

    /// Create new user
    struct CreateUserInput: Codable {
        let name: String
        let salt: String
        let verifier: String // hex format
    }

    struct CreateUserOutput: ResponseCodable {
        let name: String
    }

    @Sendable func createUser(request: Request, context: Context) async throws -> CreateUserOutput {
        let input = try await request.decode(as: CreateUserInput.self, context: context)
        guard let verifier = SRPKey(hex: input.verifier) else { throw HTTPError(.badRequest, message: "Invalid verifier") }
        let user = User(name: input.name, salt: input.salt, verifier: String(base64Encoding: verifier.bytes))
        let db = self.fluent.db()
        // check if user exists and if they don't then add new user
        let dbUser = try await User.query(on: db)
            .filter(\.$name == user.name)
            .first()
        guard dbUser == nil else { throw HTTPError(.conflict) }
        try await user.save(on: db)
        return .init(name: user.name)
    }

    struct InitLoginInput: Codable {
        let name: String
        let A: String
    }

    struct InitLoginOutput: ResponseCodable {
        let B: String
        let salt: String
    }

    @Sendable func initLogin(request: Request, context: Context) async throws -> InitLoginOutput {
        let input = try await request.decode(as: InitLoginInput.self, context: context)
        let user = try await User.query(on: self.fluent.db())
            .filter(\.$name == input.name)
            .first()

        // get data
        guard let user = user else { throw HTTPError(.unauthorized) }
        guard let A = SRPKey(hex: input.A) else { throw HTTPError(.badRequest) }
        let verifier = try SRPKey(user.verifier.base64decoded())
        // calculate server keys
        let serverKeys = self.srp.generateKeys(verifier: verifier)
        // calculate secret
        let serverSharedSecret = try self.srp.calculateSharedSecret(clientPublicKey: A, serverKeys: serverKeys, verifier: verifier)

        // store session data and return server public key, salt and session id
        let session = try SRPSession(
            userID: user.requireID(),
            state: .authenticating(
                A: String(base64Encoding: A.bytes),
                B: String(base64Encoding: serverKeys.public.bytes),
                serverSharedSecret: String(base64Encoding: serverSharedSecret.bytes)
            )
        )
        context.sessions.setSession(session)
        return .init(
            B: serverKeys.public.hex,
            salt: user.salt
        )
    }

    struct VerifyLoginInput: Codable {
        let proof: String
    }

    struct VerifyLoginOutput: ResponseCodable {
        let proof: String
    }

    @Sendable func verifyLogin(request: Request, context: Context) async throws -> VerifyLoginOutput {
        let input = try await request.decode(as: VerifyLoginInput.self, context: context)
        guard let session = context.sessions.session else {
            throw HTTPError(.unauthorized)
        }
        do {
            switch session.state {
            case .authenticating(let A, let B, let sharedSecret):
                guard let clientProof = SRPKey(hex: input.proof)?.bytes else { throw HTTPError(.badRequest) }
                // verify client proof is correct and generate server proof
                let serverProof = try srp.verifySimpleClientProof(
                    proof: clientProof,
                    clientPublicKey: SRPKey(A.base64decoded()),
                    serverPublicKey: SRPKey(B.base64decoded()),
                    sharedSecret: SRPKey(sharedSecret.base64decoded())
                )
                var session = session
                session.state = .authenticated
                context.sessions.setSession(session)
                return VerifyLoginOutput(proof: SRPKey(serverProof).hex)
            case .authenticated:
                throw HTTPError(.badRequest)
            }
        } catch SRPServerError.invalidClientProof {
            throw HTTPError(.unauthorized)
        }
    }

    @Sendable func loggedIn(request: Request, context: Context) throws -> String {
        guard let user = context.identity else { throw HTTPError(.unauthorized) }
        return "Logged in as \(user.name)"
    }
}
