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

import FluentKit
import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdCore
import WebAuthn

struct HBWebAuthnController {
    func add(_ group: HBRouterGroup) {
        group
            .post("signup", options: .editResponse, use: SignupHandler.self)
            .get("login", options: .editResponse, use: self.beginAuthentication)
        group
            .add(middleware: WebAuthnSessionAuthenticator())
            .post("beginregister", use: BeginRegistrationHandler.self)
            .post("finishregister", use: FinishRegistrationHandler.self)
            .post("login", options: .editResponse, use: FinishAuthenticationHandler.self)
            .get("test", use: self.authenticationDetails)
    }

    struct SignupHandler: HBAsyncRouteHandler {
        struct Input: Decodable {
            let name: String
        }

        typealias Output = HBResponse

        let input: Input

        init(from request: HBRequest) throws {
            self.input = try request.decode(as: Input.self)
        }

        func handle(request: HBRequest) async throws -> Output {
            guard try await User.query(on: request.db)
                .filter(\.$username == self.input.name)
                .first() == nil
            else {
                throw HBHTTPError(.conflict, message: "Username already taken.")
            }
            let user = User(username: self.input.name)
            try await user.save(on: request.db)
            let session = WebAuthnSessionAuthenticator.Session.signedUp(userId: user.id!)
            try await request.session.save(
                session: session,
                expiresIn: .minutes(10)
            )
            return .redirect(to: "/api/beginregister", type: .temporary)
        }
    }

    /// Begin registering a User
    struct BeginRegistrationHandler: HBAsyncRouteHandler {
        typealias Output = PublicKeyCredentialCreationOptions

        struct HBWebAuthUser: WebAuthnUser {
            var userID: String
            let displayName: String
            let name: String
        }

        let authenticationSession: AuthenticationSession

        init(from request: HBRequest) throws {
            self.authenticationSession = try request.authRequire(AuthenticationSession.self)
        }

        func handle(request: HBRequest) async throws -> Output {
            guard case .signedUp(let user) = self.authenticationSession else { throw HBHTTPError(.unauthorized) }
            let options = try request.webauthn.beginRegistration(user: user)
            let session = WebAuthnSessionAuthenticator.Session.registering(
                userId: user.id!,
                challenge: options.challenge
            )
            try await request.session.update(session: session, expiresIn: .minutes(10))
            return options
        }
    }

    /// Finish registering a user
    struct FinishRegistrationHandler: HBAsyncRouteHandler {
        typealias Input = RegistrationCredential
        typealias Output = HTTPResponseStatus

        let input: RegistrationCredential
        let authenticationSession: AuthenticationSession

        init(from request: HBRequest) throws {
            self.authenticationSession = try request.authRequire(AuthenticationSession.self)
            self.input = try request.decode(as: Input.self)
        }

        func handle(request: HBRequest) async throws -> Output {
            guard case .registering(let user, let challenge) = self.authenticationSession else { throw HBHTTPError(.unauthorized) }
            do {
                let credential = try await request.webauthn.finishRegistration(
                    challenge: challenge,
                    credentialCreationData: self.input,
                    // this is likely to be removed soon
                    confirmCredentialIDNotRegisteredYet: { id in
                        return try await WebAuthnCredential.query(on: request.db).filter(\.$id == id).first() == nil
                    }
                )
                try await WebAuthnCredential(credential: credential, userId: user.id!).save(on: request.db)
            } catch {
                request.logger.error("\(error)")
                throw HBHTTPError(.unauthorized)
            }
            request.logger.info("Registration success, id: \(self.input.id)")

            return .ok
        }
    }

    /// Begin Authenticating a user
    func beginAuthentication(_ request: HBRequest) async throws -> PublicKeyCredentialRequestOptions {
        let options = try request.webauthn.beginAuthentication(timeout: 60000)
        let session = WebAuthnSessionAuthenticator.Session.authenticating(
            challenge: options.challenge
        )
        try await request.session.save(session: session, expiresIn: .minutes(10))
        return options
    }

    /// End Authenticating a user
    struct FinishAuthenticationHandler: HBAsyncRouteHandler {
        typealias Input = AuthenticationCredential
        typealias Output = HTTPResponseStatus

        let input: AuthenticationCredential
        let authenticationSession: AuthenticationSession

        init(from request: HBRequest) throws {
            self.authenticationSession = try request.authRequire(AuthenticationSession.self)
            self.input = try request.decode(as: AuthenticationCredential.self)
        }

        func handle(request: HBRequest) async throws -> Output {
            guard case .authenticating(let challenge) = self.authenticationSession else { throw HBHTTPError(.unauthorized) }
            guard let webAuthnCredential = try await WebAuthnCredential.query(on: request.db)
                .filter(\.$id == input.id.asString())
                .with(\.$user)
                .first()
            else {
                throw HBHTTPError(.unauthorized)
            }
            request.logger.info("Challenge: \(challenge)")
            do {
                _ = try request.webauthn.finishAuthentication(
                    credential: self.input,
                    expectedChallenge: challenge.urlEncoded,
                    credentialPublicKey: [UInt8](webAuthnCredential.publicKey.decoded!),
                    credentialCurrentSignCount: 0
                )
            } catch {
                request.logger.error("\(error)")
                throw HBHTTPError(.unauthorized)
            }
            let session = WebAuthnSessionAuthenticator.Session.authenticated(userId: webAuthnCredential.user.id!)
            try await request.session.save(session: session, expiresIn: .hours(24))

            return .ok
        }
    }

    /// Test authenticated
    func authenticationDetails(_ request: HBRequest) throws -> AuthenticationSession {
        guard let state = request.authGet(AuthenticationSession.self) else { throw HBHTTPError(.unauthorized) }
        return state
    }
}

extension PublicKeyCredentialCreationOptions: HBResponseEncodable {}
extension PublicKeyCredentialRequestOptions: HBResponseEncodable {}
