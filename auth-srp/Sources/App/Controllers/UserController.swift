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
    static let srp = SRPServer<Insecure.SHA1>(configuration: .init(.N2048))

    /// Add routes for user controller
    func addRoutes(to group: HBRouterGroup) {
        group.post(use: CreateUser.self)
        group.post("login", options: .editResponse, use: InitLogin.self)
        group.post("verify", options: .editResponse, use: VerifyLogin.self)
        group.group()
            .add(middleware: SRPSessionAuthenticator())
            .get("loggedIn.html", use: self.loggedIn)
    }

    /// SRP session. All keys are stored as base64
    struct SRPSession: Codable {
        let userId: UUID
        let A: String // base64
        let B: String // base64
        let serverSharedSecret: String // base64
    }

    /// Create new user
    struct CreateUser: HBRouteHandler {
        struct Input: Decodable {
            let name: String
            let salt: String
            let verifier: String // hex format
        }

        struct Output: HBResponseEncodable {
            let name: String
        }

        let input: Input

        init(from request: HBRequest) throws {
            self.input = try request.decode(as: Input.self)
        }

        func handle(request: HBRequest) -> EventLoopFuture<Output> {
            guard let verifier = SRPKey(hex: input.verifier) else { return request.failure(.badRequest) }
            let user = User(name: input.name, salt: self.input.salt, verifier: String(base64Encoding: verifier.bytes))
            // check if user exists and if they don't then add new user
            return User.query(on: request.db)
                .filter(\.$name == user.name)
                .first()
                .flatMapThrowing { user -> Void in
                    // if user already exist throw conflict
                    guard user == nil else { throw HBHTTPError(.conflict) }
                    return
                }
                .flatMap { _ in
                    return user.save(on: request.db)
                }
                .transform(to: Output(name: user.name))
        }
    }

    /// Login user and create session
    struct InitLogin: HBRouteHandler {
        struct Input: Decodable {
            let name: String
            let A: String
        }

        struct Output: HBResponseEncodable {
            let B: String
            let salt: String
        }

        let input: Input

        init(from request: HBRequest) throws {
            self.input = try request.decode(as: Input.self)
        }

        func handle(request: HBRequest) -> EventLoopFuture<Output> {
            return User.query(on: request.db)
                .filter(\.$name == self.input.name)
                .first()
                .flatMap { user -> EventLoopFuture<Output> in
                    do {
                        // get data
                        guard let user = user else { throw HBHTTPError(.unauthorized) }
                        guard let A = SRPKey(hex: input.A) else { throw HBHTTPError(.badRequest) }
                        let verifier = try SRPKey(user.verifier.base64decoded())
                        // calculate server keys
                        let serverKeys = UserController.srp.generateKeys(verifier: verifier)
                        // calculate secret
                        let serverSharedSecret = try UserController.srp.calculateSharedSecret(clientPublicKey: A, serverKeys: serverKeys, verifier: verifier)

                        // store session data and return server public key, salt and session id
                        let session = try SRPSessionAuthenticator.Session(
                            userId: user.requireID(),
                            state: .authenticating(
                                A: String(base64Encoding: A.bytes),
                                B: String(base64Encoding: serverKeys.public.bytes),
                                serverSharedSecret: String(base64Encoding: serverSharedSecret.bytes)
                            )
                        )
                        return request.session.save(session: session, expiresIn: .minutes(10))
                            .map { _ in
                                return .init(
                                    B: serverKeys.public.hex,
                                    salt: user.salt
                                )
                            }
                    } catch {
                        return request.failure(error)
                    }
                }
        }
    }

    /// Verify login secret from client and return server proof of secret
    struct VerifyLogin: HBRouteHandler {
        struct Input: Decodable {
            let proof: String
        }

        struct Output: HBResponseEncodable {
            let proof: String
        }

        let input: Input

        init(from request: HBRequest) throws {
            self.input = try request.decode(as: Input.self)
        }

        func handle(request: HBRequest) -> EventLoopFuture<Output> {
            return request.session.load(as: SRPSessionAuthenticator.Session.self)
                .flatMap { session in
                    do {
                        guard let session = session else { return request.failure(.unauthorized) }
                        switch session.state {
                        case .authenticating(let A, let B, let sharedSecret):
                            guard let clientProof = SRPKey(hex: input.proof)?.bytes else { throw HBHTTPError(.badRequest) }
                            // verify client proof is correct and generate server proof
                            let serverProof = try srp.verifySimpleClientProof(
                                proof: clientProof,
                                clientPublicKey: SRPKey(A.base64decoded()),
                                serverPublicKey: SRPKey(B.base64decoded()),
                                sharedSecret: SRPKey(sharedSecret.base64decoded())
                            )
                            var session = session
                            session.state = .authenticated
                            // set session state to authenticated and return server proof
                            return request.session.save(session: session, expiresIn: .hours(24))
                                .map { _ in
                                    return Output(proof: SRPKey(serverProof).hex)
                                }
                        case .authenticated:
                            return request.failure(.badRequest)
                        }
                    } catch SRPServerError.invalidClientProof {
                        return request.failure(.unauthorized)
                    } catch {
                        return request.failure(error)
                    }
                }
        }
    }

    func loggedIn(request: HBRequest) throws -> String {
        let user = try request.authRequire(User.self)
        return "Logged in as \(user.name)"
    }
}
