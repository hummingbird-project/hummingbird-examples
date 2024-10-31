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

@testable import App
import Crypto
import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import SRP
import XCTest

final class AppTests: XCTestCase {
    struct TestArguments: AppArguments {
        var hostname = "localhost"
        var port = 8080
        var logLevel: Logger.Level? = .trace
        var migrate = true
        var inMemoryDatabase = true
    }

    func testApp() async throws {
        let srpClient = SRPClient(configuration: SRPConfiguration<Insecure.SHA1>(.N2048))
        let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
            let (salt, verifier) = srpClient.generateSaltAndVerifier(username: "JohnSmith", password: "1234567890")
            let createUser = UserController.CreateUserInput(name: "JohnSmith", salt: salt.hexDigest(), verifier: verifier.hex)
            let createUserBody = try JSONEncoder().encode(createUser)
            try await client.execute(uri: "/api/user", method: .post, body: .init(data: createUserBody)) { response in
                XCTAssertEqual(response.status, .ok)
            }

            let keys = srpClient.generateKeys()
            let initLogin = UserController.InitLoginInput(name: "JohnSmith", A: keys.public.hex)
            let initLoginBody = try JSONEncoder().encode(initLogin)
            let (initLoginResponse, cookies) = try await client.execute(
                uri: "/api/user/login",
                method: .post,
                body: .init(data: initLoginBody)
            ) { response -> (UserController.InitLoginOutput, String) in
                XCTAssertEqual(response.status, .ok)
                let cookies = try XCTUnwrap(response.headers[.setCookie])
                let initLoginResponse = try JSONDecoder().decode(UserController.InitLoginOutput.self, from: response.body)
                return (initLoginResponse, cookies)
            }
            let serverPublicKey = try XCTUnwrap(SRPKey(hex: initLoginResponse.B))
            let sharedSecret = try srpClient.calculateSharedSecret(
                username: "JohnSmith",
                password: "1234567890",
                salt: salt,
                clientKeys: keys,
                serverPublicKey: serverPublicKey
            )
            // The SRP client has a non-standard shared secret proof
            // The client proof is M = H(A+B+K) with everything padded
            // The server proof is M2 = H(A+M+K) with everything padded
            let A = keys.public
            let B = serverPublicKey
            let K = SRPKey(srpClient.hash(data: sharedSecret.unpaddedBytes), padding: srpClient.configuration.sizeN)
            let clientProof = [UInt8](srpClient.hash(data: A.bytes + B.bytes + K.bytes))
            let verifyLogin = UserController.VerifyLoginInput(proof: clientProof.hexDigest())
            let verifyLoginBody = try JSONEncoder().encode(verifyLogin)
            try await client.execute(
                uri: "/api/user/verify",
                method: .post,
                headers: [.cookie: cookies],
                body: .init(data: verifyLoginBody)
            ) { response in
                XCTAssertEqual(response.status, .ok)
                let verifyLoginResponse = try JSONDecoder().decode(UserController.VerifyLoginOutput.self, from: response.body)
                let serverProof = try XCTUnwrap(SRPKey(hex: verifyLoginResponse.proof))
                // verify server proof
                let M = SRPKey(clientProof, padding: srpClient.configuration.sizeN)
                let calculatedServerProof = [UInt8](srpClient.hash(data: A.bytes + M.bytes + K.bytes))
                XCTAssertEqual(serverProof.bytes, calculatedServerProof)
            }
        }
    }
}

extension Sequence where Element == UInt8 {
    /// return a hexEncoded string buffer from an array of bytes
    func hexDigest() -> String {
        return self.map { String(format: "%02x", $0) }.joined(separator: "")
    }
}
