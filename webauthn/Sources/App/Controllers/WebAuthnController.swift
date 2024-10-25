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

struct WebAuthnController: RouterController {
    typealias Context = WebAuthnRequestContext

    let webauthn: WebAuthnManager
    let fluent: Fluent
    let webAuthnSessionAuthenticator: SessionAuthenticator<Context, UserRepository>

    // return RouteGroup with user login endpoints
    var body: some RouterMiddleware<Context> {
        return RouteGroup("user") {
            Post("signup", handler: self.signup)
            Get("login", handler: self.beginAuthentication)
            Post("login", handler: self.finishAuthentication)
            Get("logout") {
                self.webAuthnSessionAuthenticator
                self.logout
            }
            RouteGroup("register") {
                Post("start", handler: self.beginRegistration)
                Post("finish", handler: self.finishRegistration)
            }
        }
    }

    struct SignUpInput: Decodable {
        let username: String
    }

    @Sendable func signup(request: Request, context: Context) async throws -> Response {
        let input = try await request.decode(as: SignUpInput.self, context: context)
        guard try await User.query(on: self.fluent.db())
            .filter(\.$username == input.username)
            .first() == nil
        else {
            throw HTTPError(.conflict, message: "Username already taken.")
        }
        let user = User(username: input.username)
        try await user.save(on: self.fluent.db())
        try context.sessions.setSession(.signedUp(userId: user.requireID()), expiresIn: .seconds(600))
        return .redirect(to: "/api/user/register/start", type: .temporary)
    }

    /// Begin registering a User
    @Sendable func beginRegistration(request: Request, context: Context) async throws -> PublicKeyCredentialCreationOptions {
        let registrationSession = try await context.sessions.session?.session(fluent: self.fluent)
        guard case .signedUp(let user) = registrationSession else { throw HTTPError(.unauthorized) }
        let options = try self.webauthn.beginRegistration(user: user.publicKeyCredentialUserEntity)
        let session = try WebAuthnSession(from: .registering(
            user: user,
            challenge: options.challenge
        ))
        context.sessions.setSession(session, expiresIn: .seconds(600))
        return options
    }

    /// Finish registering a user
    @Sendable func finishRegistration(request: Request, context: Context) async throws -> HTTPResponse.Status {
        let registrationSession = try await context.sessions.session?.session(fluent: self.fluent)
        let input = try await request.decode(as: RegistrationCredential.self, context: context)
        guard case .registering(let user, let challenge) = registrationSession else { throw HTTPError(.unauthorized) }
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
        context.sessions.clearSession()
        context.logger.info("Registration success, id: \(input.id)")

        return .ok
    }

    /// Begin Authenticating a user
    @Sendable func beginAuthentication(_ request: Request, context: Context) async throws -> PublicKeyCredentialRequestOptions {
        let options = try self.webauthn.beginAuthentication(timeout: 60000)
        let session = try WebAuthnSession(from: .authenticating(
            challenge: options.challenge
        ))
        context.sessions.setSession(session, expiresIn: .seconds(600))
        return options
    }

    /// End Authenticating a user
    @Sendable func finishAuthentication(request: Request, context: Context) async throws -> HTTPResponse.Status {
        let authenticationSession = try await context.sessions.session?.session(fluent: self.fluent)
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
        try context.sessions.setSession(.authenticated(userId: webAuthnCredential.user.requireID()), expiresIn: .seconds(24 * 60 * 60))
        return .ok
    }

    /// Test authenticated
    @Sendable func logout(_ request: Request, context: Context) async throws -> HTTPResponse.Status {
        context.sessions.clearSession()
        return .ok
    }
}

#if hasFeature(RetroactiveAttribute)
extension PublicKeyCredentialCreationOptions: @retroactive ResponseEncodable {}
extension PublicKeyCredentialRequestOptions: @retroactive ResponseEncodable {}
#else
extension PublicKeyCredentialCreationOptions: ResponseEncodable {}
extension PublicKeyCredentialRequestOptions: ResponseEncodable {}
#endif
