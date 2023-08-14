//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
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
    let webauthn: WebAuthnManager

    func add(to group: HBRouterGroup) {
        group
            .post("signup", options: .editResponse, use: self.signin)
            .get("login", options: .editResponse, use: self.beginAuthentication)
        group
            .add(middleware: WebAuthnSessionStateAuthenticator())
            .post("register/start", use: self.beginRegistration)
            .post("register/finish", use: self.finishRegistration)
            .post("login", options: .editResponse, use: self.finishAuthentication)
        group
            .add(middleware: WebAuthnSessionAuthenticator())
            .get("logout", options: .editResponse, use: self.logout)
    }

    struct SignInInput: Decodable {
        let username: String
    }

    func signin(request: HBRequest) async throws -> HBResponse {
        let input = try request.decode(as: SignInInput.self)
        guard try await User.query(on: request.db)
            .filter(\.$username == input.username)
            .first() == nil
        else {
            throw HBHTTPError(.conflict, message: "Username already taken.")
        }
        let user = User(username: input.username)
        try await user.save(on: request.db)
        let session = try WebAuthnSessionStateAuthenticator.Session.signedUp(userId: user.requireID())
        try await request.session.save(
            session: session,
            expiresIn: .minutes(10)
        )
        return .redirect(to: "/api/register/start", type: .temporary)
    }

    /// Begin registering a User
    func beginRegistration(request: HBRequest) async throws -> PublicKeyCredentialCreationOptions {
        let authenticationSession = try request.authRequire(AuthenticationSession.self)
        guard case .signedUp(let user) = authenticationSession else { throw HBHTTPError(.unauthorized) }
        let options = self.webauthn.beginRegistration(user: user.publicKeyCredentialUserEntity)
        let session = WebAuthnSessionStateAuthenticator.Session(from: .registering(
            user: user,
            challenge: options.challenge
        ))
        try await request.session.update(session: session, expiresIn: .minutes(10))
        return options
    }

    /// Finish registering a user
    func finishRegistration(request: HBRequest) async throws -> HTTPResponseStatus {
        let authenticationSession = try request.authRequire(AuthenticationSession.self)
        let input = try request.decode(as: RegistrationCredential.self)
        guard case .registering(let user, let challenge) = authenticationSession else { throw HBHTTPError(.unauthorized) }
        do {
            let credential = try await self.webauthn.finishRegistration(
                challenge: challenge,
                credentialCreationData: input,
                // this is likely to be removed soon
                confirmCredentialIDNotRegisteredYet: { id in
                    return try await WebAuthnCredential.query(on: request.db).filter(\.$id == id).first() == nil
                }
            )
            try await WebAuthnCredential(credential: credential, userId: user.requireID()).save(on: request.db)
        } catch {
            request.logger.error("\(error)")
            throw HBHTTPError(.unauthorized)
        }
        request.logger.info("Registration success, id: \(input.id)")

        return .ok
    }

    /// Begin Authenticating a user
    func beginAuthentication(_ request: HBRequest) async throws -> PublicKeyCredentialRequestOptions {
        let options = try self.webauthn.beginAuthentication(timeout: 60000)
        let session = WebAuthnSessionAuthenticator.Session(from: .authenticating(
            challenge: options.challenge
        ))
        try await request.session.save(session: session, expiresIn: .minutes(10))
        return options
    }

    /// End Authenticating a user
    func finishAuthentication(request: HBRequest) async throws -> HTTPResponseStatus {
        let authenticationSession = try request.authRequire(AuthenticationSession.self)
        let input = try request.decode(as: AuthenticationCredential.self)
        guard case .authenticating(let challenge) = authenticationSession else { throw HBHTTPError(.unauthorized) }
        let id = input.id.urlDecoded.asString()
        guard let webAuthnCredential = try await WebAuthnCredential.query(on: request.db)
            .filter(\.$id == id)
            .with(\.$user)
            .first()
        else {
            throw HBHTTPError(.unauthorized)
        }
        guard let decodedPublicKey = webAuthnCredential.publicKey.decoded else { throw HBHTTPError(.internalServerError) }
        request.logger.info("Challenge: \(challenge)")
        do {
            _ = try self.webauthn.finishAuthentication(
                credential: input,
                expectedChallenge: challenge,
                credentialPublicKey: [UInt8](decodedPublicKey),
                credentialCurrentSignCount: 0
            )
        } catch {
            request.logger.error("\(error)")
            throw HBHTTPError(.unauthorized)
        }
        let session = try WebAuthnSessionAuthenticator.Session.authenticated(userId: webAuthnCredential.user.requireID())
        try await request.session.update(session: session, expiresIn: .hours(24))

        return .ok
    }

    /// Test authenticated
    func logout(_ request: HBRequest) async throws -> HTTPResponseStatus {
        try await request.session.delete()
        return .ok
    }
}

extension PublicKeyCredentialCreationOptions: HBResponseEncodable {}
extension PublicKeyCredentialRequestOptions: HBResponseEncodable {}
