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
            .post("beginregister", options: .editResponse, use: BeginRegistrationHandler.self)
            .post("finishregister", use: FinishRegistrationHandler.self)
            .get("login", options: .editResponse, use: self.beginAuthentication)
            .post("login", options: .editResponse, use: FinishAuthenticationHandler.self)
            .add(middleware: WebAuthnSessionAuthenticator())
            .get("test", use: self.test)
    }

    /// Begin registering a User
    struct BeginRegistrationHandler: HBAsyncRouteHandler {
        struct Input: Decodable {
            let displayName: String
            let name: String
        }

        typealias Output = PublicKeyCredentialCreationOptions

        struct HBWebAuthUser: WebAuthn.User {
            var userID: String
            let displayName: String
            let name: String
        }

        let input: Input

        init(from request: HBRequest) throws {
            self.input = try request.decode(as: Input.self)
        }

        func handle(request: HBRequest) async throws -> Output {
            let user = HBWebAuthUser(userID: UUID().uuidString, displayName: self.input.displayName, name: self.input.name)
            let options = try request.webauthn.beginRegistration(user: user)
            try await request.session.save(session: WebAuthnSessionAuthenticator.Session.registering(challenge: options.challenge), expiresIn: .minutes(10))
            return options
        }
    }

    /// Finish registering a user
    struct FinishRegistrationHandler: HBAsyncRouteHandler {
        typealias Input = RegistrationCredential
        typealias Output = HTTPResponseStatus

        let input: RegistrationCredential

        init(from request: HBRequest) throws {
            self.input = try request.decode(as: Input.self)
        }

        func handle(request: HBRequest) async throws -> Output {
            guard let session = try await request.session.load(as: WebAuthnSessionAuthenticator.Session.self) else { throw HBHTTPError(.unauthorized) }
            guard case .registering(let challenge) = session else { throw HBHTTPError(.unauthorized) }
            do {
                let credential = try await request.webauthn.finishRegistration(
                    challenge: challenge,
                    credentialCreationData: self.input,
                    // this is likely to be removed soon
                    confirmCredentialIDNotRegisteredYet: { _ in
                        return try await HBWebAuthnController.queryUserWithWebAuthnId(self.input.id, request: request) == nil
                    }
                )
                try await User(from: credential).save(on: request.db)
            } catch {
                request.logger.error("\(error)")
            }
            request.logger.info("Registration success, id: \(self.input.id)")

            return .ok
        }
    }

    /// Begin Authenticating a user
    func beginAuthentication(_ request: HBRequest) async throws -> PublicKeyCredentialRequestOptions {
        let options = try request.webauthn.beginAuthentication(timeout: 60000)
        let challenge = String.base64URL(fromBase64: options.challenge)
        request.logger.info("Challenge: \(challenge)")
        try await request.session.save(session: WebAuthnSessionAuthenticator.Session.authenticating(challenge: challenge), expiresIn: .minutes(10))
        return options
    }

    /// End Authenticating a user
    struct FinishAuthenticationHandler: HBAsyncRouteHandler {
        typealias Input = AuthenticationCredential
        typealias Output = HTTPResponseStatus

        let input: AuthenticationCredential

        init(from request: HBRequest) throws {
            self.input = try request.decode(as: AuthenticationCredential.self)
        }

        func handle(request: HBRequest) async throws -> Output {
            guard let session = try await request.session.load(as: WebAuthnSessionAuthenticator.Session.self) else { throw HBHTTPError(.unauthorized) }
            guard case .authenticating(let challenge) = session else { throw HBHTTPError(.unauthorized) }

            guard let user = try await HBWebAuthnController.queryUserWithWebAuthnId(self.input.id, request: request) else {
                throw HBHTTPError(.unauthorized)
            }
            request.logger.info("Challenge: \(challenge)")
            do {
                _ = try request.webauthn.finishAuthentication(
                    credential: self.input,
                    expectedChallenge: challenge,
                    credentialPublicKey: [UInt8](user.publicKey.base64URLDecodedData!),
                    credentialCurrentSignCount: 0
                )
            } catch {
                request.logger.error("\(error)")
                throw HBHTTPError(.unauthorized)
            }
            try await request.session.save(session: WebAuthnSessionAuthenticator.Session.authenticated(userId: user.id!), expiresIn: .hours(24))

            return .ok
        }
    }

    /// Test authenticated
    func test(_ request: HBRequest) throws -> HTTPResponseStatus {
        guard request.authHas(User.self) else { throw HBHTTPError(.unauthorized) }
        return .ok
    }

    static func queryUserWithWebAuthnId(_ id: String, request: HBRequest) async throws -> User? {
        return try await User.query(on: request.db)
            .filter(\.$webAuthnId == id)
            .first()
    }
}

extension PublicKeyCredentialCreationOptions: HBResponseEncodable {}
extension PublicKeyCredentialRequestOptions: HBResponseEncodable {}
