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
    let fluent: Fluent
    let webAuthnSessionAuthenticator: SessionAuthenticator<Context, UserRepository>

    // return RouteGroup with user login endpoints
    var endpoints: some RouterMiddleware<Context> {
        /// Authenticator storing the WebAuthn session state
        let webAuthnSessionStateAuthenticator = SessionAuthenticator(
            sessionStorage: self.webAuthnSessionAuthenticator.sessionStorage,
            context: Context.self
        ) { (session: WebAuthnSession, _) in
            return try await session.session(fluent: self.fluent)
        }

        return RouteGroup("user") {
            Post("signup", handler: self.signin)
            Get("login", handler: self.beginAuthentication)
            Post("login") {
                webAuthnSessionStateAuthenticator
                self.finishAuthentication
            }
            Get("logout") {
                self.webAuthnSessionAuthenticator
                self.logout
            }
            RouteGroup("register") {
                webAuthnSessionStateAuthenticator
                Post("start", handler: self.beginRegistration)
                Post("finish", handler: self.finishRegistration)
            }
        }
    }

    struct SignInInput: Decodable {
        let username: String
    }

    @Sendable func signin(request: Request, context: Context) async throws -> Response {
        let input = try await request.decode(as: SignInInput.self, context: context)
        guard try await User.query(on: self.fluent.db())
            .filter(\.$username == input.username)
            .first() == nil
        else {
            throw HTTPError(.conflict, message: "Username already taken.")
        }
        let user = User(username: input.username)
        try await user.save(on: self.fluent.db())
        let session = try WebAuthnSession.signedUp(userId: user.requireID())
        let cookie = try await self.webAuthnSessionAuthenticator.sessionStorage.save(
            session: session,
            expiresIn: .seconds(600)
        )
        var response = Response.redirect(to: "/api/user/register/start", type: .temporary)
        response.setCookie(cookie)
        return response
    }

    /// Begin registering a User
    @Sendable func beginRegistration(request: Request, context: Context) async throws -> PublicKeyCredentialCreationOptions {
        let authenticationSession = try context.auth.require(AuthenticationSession.self)
        guard case .signedUp(let user) = authenticationSession else { throw HTTPError(.unauthorized) }
        let options = try self.webauthn.beginRegistration(user: user.publicKeyCredentialUserEntity)
        let session = try WebAuthnSession(from: .registering(
            user: user,
            challenge: options.challenge
        ))
        try await self.webAuthnSessionAuthenticator.sessionStorage.update(session: session, expiresIn: .seconds(600), request: request)
        return options
    }

    /// Finish registering a user
    @Sendable func finishRegistration(request: Request, context: Context) async throws -> HTTPResponse.Status {
        let authenticationSession = try context.auth.require(AuthenticationSession.self)
        let input = try await request.decode(as: RegistrationCredential.self, context: context)
        guard case .registering(let user, let challenge) = authenticationSession else { throw HTTPError(.unauthorized) }
        do {
            let credential = try await self.webauthn.finishRegistration(
                challenge: challenge,
                credentialCreationData: input,
                // this is likely to be removed soon
                confirmCredentialIDNotRegisteredYet: { id in
                    return try await WebAuthnCredential.query(on: self.fluent.db()).filter(\.$id == id).first() == nil
                }
            )
            try await WebAuthnCredential(credential: credential, userId: user.requireID()).save(on: self.fluent.db())
        } catch {
            context.logger.error("\(error)")
            throw HTTPError(.unauthorized)
        }
        context.logger.info("Registration success, id: \(input.id)")

        return .ok
    }

    /// Begin Authenticating a user
    @Sendable func beginAuthentication(_ request: Request, context: Context) async throws -> EditedResponse<PublicKeyCredentialRequestOptions> {
        let options = try self.webauthn.beginAuthentication(timeout: 60000)
        let session = try WebAuthnSession(from: .authenticating(
            challenge: options.challenge
        ))
        let cookie = try await self.webAuthnSessionAuthenticator.sessionStorage.save(session: session, expiresIn: .seconds(600))
        var editedResponse = EditedResponse(response: options)
        editedResponse.setCookie(cookie)
        return editedResponse
    }

    /// End Authenticating a user
    @Sendable func finishAuthentication(request: Request, context: Context) async throws -> HTTPResponse.Status {
        let authenticationSession = try context.auth.require(AuthenticationSession.self)
        let input = try await request.decode(as: AuthenticationCredential.self, context: context)
        guard case .authenticating(let challenge) = authenticationSession else { throw HTTPError(.unauthorized) }
        let id = input.id.urlDecoded.asString()
        guard let webAuthnCredential = try await WebAuthnCredential.query(on: fluent.db())
            .filter(\.$id == id)
            .with(\.$user)
            .first()
        else {
            throw HTTPError(.unauthorized)
        }
        guard let decodedPublicKey = webAuthnCredential.publicKey.decoded else { throw HTTPError(.internalServerError) }
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
            throw HTTPError(.unauthorized)
        }
        let session = try WebAuthnSession.authenticated(userId: webAuthnCredential.user.requireID())
        try await self.webAuthnSessionAuthenticator.sessionStorage.update(session: session, expiresIn: .seconds(24 * 60 * 60), request: request)

        return .ok
    }

    /// Test authenticated
    @Sendable func logout(_ request: Request, context: Context) async throws -> HTTPResponse.Status {
        try await self.webAuthnSessionAuthenticator.sessionStorage.delete(request: request)
        return .ok
    }
}

extension PublicKeyCredentialCreationOptions: ResponseEncodable {}
extension PublicKeyCredentialRequestOptions: ResponseEncodable {}
