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
import HummingbirdFluent
import HummingbirdRouter
import WebAuthn

struct HBWebAuthnController {
    typealias Context = WebAuthnRequestContext

    let webauthn: WebAuthnManager
    let fluent: HBFluent
    let sessionStorage: HBSessionStorage

    var endpoints: some HBMiddlewareProtocol<Context> {
        RouteGroup("user") {
            Post("signup", handler: self.signin)
            Get("login", handler: self.beginAuthentication)
            Post("login") {
                WebAuthnSessionStateAuthenticator(fluent: self.fluent, sessionStorage: self.sessionStorage)
                self.finishAuthentication
            }
            Get("logout") {
                WebAuthnSessionAuthenticator(fluent: self.fluent, sessionStorage: self.sessionStorage)
                self.logout
            }
            RouteGroup("register") {
                WebAuthnSessionStateAuthenticator(fluent: self.fluent, sessionStorage: self.sessionStorage)
                Post("start", handler: self.beginRegistration)
                Post("finish", handler: self.finishRegistration)
            }
        }
    }

    struct SignInInput: Decodable {
        let username: String
    }

    @Sendable func signin(request: HBRequest, context: Context) async throws -> HBResponse {
        let input = try await request.decode(as: SignInInput.self, context: context)
        guard try await User.query(on: self.fluent.db())
            .filter(\.$username == input.username)
            .first() == nil
        else {
            throw HBHTTPError(.conflict, message: "Username already taken.")
        }
        let user = User(username: input.username)
        try await user.save(on: self.fluent.db())
        let session = try WebAuthnSession.signedUp(userId: user.requireID())
        let cookie = try await self.sessionStorage.save(
            session: session,
            expiresIn: .seconds(600)
        )
        var response = HBResponse.redirect(to: "/api/user/register/start", type: .temporary)
        response.setCookie(cookie)
        return response
    }

    /// Begin registering a User
    @Sendable func beginRegistration(request: HBRequest, context: Context) async throws -> PublicKeyCredentialCreationOptions {
        let authenticationSession = try context.auth.require(AuthenticationSession.self)
        guard case .signedUp(let user) = authenticationSession else { throw HBHTTPError(.unauthorized) }
        let options = self.webauthn.beginRegistration(user: user.publicKeyCredentialUserEntity)
        let session = WebAuthnSession(from: .registering(
            user: user,
            challenge: options.challenge
        ))
        try await self.sessionStorage.update(session: session, expiresIn: .seconds(600), request: request)
        return options
    }

    /// Finish registering a user
    @Sendable func finishRegistration(request: HBRequest, context: Context) async throws -> HTTPResponse.Status {
        let authenticationSession = try context.auth.require(AuthenticationSession.self)
        let input = try await request.decode(as: RegistrationCredential.self, context: context)
        guard case .registering(let user, let challenge) = authenticationSession else { throw HBHTTPError(.unauthorized) }
        do {
            let credential = try await self.webauthn.finishRegistration(
                challenge: challenge,
                credentialCreationData: input,
                // this is likely to be removed soon
                confirmCredentialIDNotRegisteredYet: { id in
                    return try await WebAuthnCredential.query(on: self.fluent.db()).filter(\.$id == id).first() == nil
                }
            )
            try await WebAuthnCredential(credential: credential, userId: user.id).save(on: self.fluent.db())
        } catch {
            context.logger.error("\(error)")
            throw HBHTTPError(.unauthorized)
        }
        context.logger.info("Registration success, id: \(input.id)")

        return .ok
    }

    /// Begin Authenticating a user
    @Sendable func beginAuthentication(_ request: HBRequest, context: Context) async throws -> HBEditedResponse<PublicKeyCredentialRequestOptions> {
        let options = try self.webauthn.beginAuthentication(timeout: 60000)
        let session = WebAuthnSession(from: .authenticating(
            challenge: options.challenge
        ))
        let cookie = try await sessionStorage.save(session: session, expiresIn: .seconds(600))
        var editedResponse = HBEditedResponse(response: options)
        editedResponse.setCookie(cookie)
        return editedResponse
    }

    /// End Authenticating a user
    @Sendable func finishAuthentication(request: HBRequest, context: Context) async throws -> HTTPResponse.Status {
        let authenticationSession = try context.auth.require(AuthenticationSession.self)
        let input = try await request.decode(as: AuthenticationCredential.self, context: context)
        guard case .authenticating(let challenge) = authenticationSession else { throw HBHTTPError(.unauthorized) }
        let id = input.id.urlDecoded.asString()
        guard let webAuthnCredential = try await WebAuthnCredential.query(on: fluent.db())
            .filter(\.$id == id)
            .with(\.$user)
            .first()
        else {
            throw HBHTTPError(.unauthorized)
        }
        guard let decodedPublicKey = webAuthnCredential.publicKey.decoded else { throw HBHTTPError(.internalServerError) }
        context.logger.info("Challenge: \(challenge)")
        do {
            _ = try self.webauthn.finishAuthentication(
                credential: input,
                expectedChallenge: challenge,
                credentialPublicKey: [UInt8](decodedPublicKey),
                credentialCurrentSignCount: 0
            )
        } catch {
            context.logger.error("\(error)")
            throw HBHTTPError(.unauthorized)
        }
        let session = try WebAuthnSession.authenticated(userId: webAuthnCredential.user.requireID())
        try await self.sessionStorage.update(session: session, expiresIn: .seconds(24 * 60 * 60), request: request)

        return .ok
    }

    /// Test authenticated
    @Sendable func logout(_ request: HBRequest, context: Context) async throws -> HTTPResponse.Status {
        try await self.sessionStorage.delete(request: request)
        return .ok
    }
}

extension PublicKeyCredentialCreationOptions: HBResponseEncodable {}
extension PublicKeyCredentialRequestOptions: HBResponseEncodable {}
