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
        group.post("bignum", use: Bignum.self)
        group.post("login", use: InitLogin.self)
        group.post("verify", use: FinalizeLogin.self)
        group.add(middleware: SessionAuthenticator())
            .get(use: CurrentUser.self)
    }

    /// SRP session. All keys are stored as base64
    struct SRPSession: Codable {
        let userId: UUID
        let name: String
        let salt: String
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
            let user = User(name: input.name, salt: input.salt, verifier: String(base64Encoding: verifier.bytes))
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
            let sessionId: String
        }
        let input: Input

        init(from request: HBRequest) throws {
            self.input = try request.decode(as: Input.self)
        }
        func handle(request: HBRequest) -> EventLoopFuture<Output> {
            return User.query(on: request.db)
                .filter(\.$name == input.name)
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
                        // create session key and pass public server key and salt back to client
                        let sessionKey = HBRequest.Session.createSessionId()
                        let session = try SRPSession(
                            userId: user.requireID(),
                            name: user.name,
                            salt: user.salt,
                            A: input.A,
                            B: String(base64Encoding: serverKeys.public.bytes),
                            serverSharedSecret: String(base64Encoding: serverSharedSecret.bytes)
                        )
                        let sessionId = "srp.\(sessionKey)"
                        return request.persist.create(key: sessionId, value: session, expires: .minutes(10))
                            .map { _ in
                                return .init(
                                    B: serverKeys.public.hex,
                                    salt: user.salt,
                                    sessionId: sessionId
                                )
                            }
                    } catch {
                        return request.failure(error)
                    }
                }
        }
    }

    /// Login user and create session
    struct FinalizeLogin: HBRouteHandler {
        struct Input: Decodable {
            let sessionId: String
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
            return request.persist.get(key: input.sessionId, as: SRPSession.self)
                .flatMap { session in
                    do {
                        guard let session = session else { throw HBHTTPError(.badRequest) }
/*                        let clientProof = try input.proof.base64decoded()
                        let serverProof = try srp.verifyClientProof(
                            proof: clientProof,
                            username: session.name,
                            salt: session.salt.base64decoded(),
                            clientPublicKey: SRPKey(session.A.base64decoded()),
                            serverPublicKey: SRPKey(session.B.base64decoded()),
                            sharedSecret: SRPKey(session.serverSharedSecret.base64decoded())
                        )*/
                        let clientSecret = SRPKey(hex: input.proof)
                        guard try clientSecret?.bytes == session.serverSharedSecret.base64decoded() else {
                            throw HBHTTPError(.unauthorized)
                        }
                        return request.session.save(userId: session.userId, expiresIn: .hours(1)).map { _ in
                            return .init(proof: session.serverSharedSecret)
                        }
                    } catch {
                        return request.failure(error)
                    }
                }
        }
    }

    /// Get current logged in user
    struct CurrentUser: HBRouteHandler {
        struct Output: HBResponseEncodable {
            let name: String
        }
        let user: User
        init(from request: HBRequest) throws {
            self.user = try request.auth.require(User.self)
        }
        func handle(request: HBRequest) -> Output {
            return Output(name: user.name)
        }
    }
}
