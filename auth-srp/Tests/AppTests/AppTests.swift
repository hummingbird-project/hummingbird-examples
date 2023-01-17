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
import HummingbirdXCT
import SRP
import XCTest

final class AppTests: XCTestCase {
    struct TestArguments: AppArguments {
        var migrate: Bool { true }
        var inMemoryDatabase: Bool { true }
    }

    func testApp() throws {
        let srpClient = SRPClient(configuration: SRPConfiguration<Insecure.SHA1>(.N2048))
        let app = HBApplication(testing: .live)
        try app.configure(TestArguments())

        try app.XCTStart()
        defer { app.XCTStop() }

        let (salt, verifier) = srpClient.generateSaltAndVerifier(username: "JohnSmith", password: "1234567890")
        let createUser = UserController.CreateUser.Input(name: "JohnSmith", salt: salt.hexDigest(), verifier: verifier.hex)
        let createUserBody = try JSONEncoder().encode(createUser)
        try app.XCTExecute(uri: "/api/user", method: .POST, body: .init(data: createUserBody)) { response in
            XCTAssertEqual(response.status, .ok)
        }

        let keys = srpClient.generateKeys()
        let initLogin = UserController.InitLogin.Input(name: "JohnSmith", A: keys.public.hex)
        let initLoginBody = try JSONEncoder().encode(initLogin)
        let (initLoginResponse, cookies) = try app.XCTExecute(
            uri: "/api/user/login",
            method: .POST,
            body: .init(data: initLoginBody)
        ) { response -> (output: UserController.InitLogin.Output, cookies: String) in
            XCTAssertEqual(response.status, .ok)
            let cookies = try XCTUnwrap(response.headers["set-cookie"].first)
            let body = try XCTUnwrap(response.body)
            let initLoginResponse = try JSONDecoder().decode(UserController.InitLogin.Output.self, from: Data(buffer: body))
            return (output: initLoginResponse, cookies: cookies)
        }
        let serverPublicKey = try XCTUnwrap(SRPKey(hex: initLoginResponse.B))
        let sharedSecret = try srpClient.calculateSharedSecret(
            username: "JohnSmith",
            password: "1234567890",
            salt: salt,
            clientKeys: keys,
            serverPublicKey: serverPublicKey
        )
        let proof = srpClient.calculateSimpleClientProof(
            clientPublicKey: keys.public,
            serverPublicKey: serverPublicKey,
            sharedSecret: sharedSecret
        )
        let verifyLogin = UserController.VerifyLogin.Input(proof: proof.hexDigest())
        let verifyLoginBody = try JSONEncoder().encode(verifyLogin)
        try app.XCTExecute(
            uri: "/api/user/verify",
            method: .POST,
            headers: ["cookie": cookies],
            body: .init(data: verifyLoginBody)
        ) { response in
            XCTAssertEqual(response.status, .ok)
            let body = try XCTUnwrap(response.body)
            let verifyLoginResponse = try JSONDecoder().decode(UserController.VerifyLogin.Output.self, from: Data(buffer: body))
            let serverProof = try XCTUnwrap(SRPKey(hex: verifyLoginResponse.proof))
            try srpClient.verifySimpleServerProof(
                serverProof: serverProof.bytes,
                clientProof: proof,
                clientKeys: keys,
                sharedSecret: sharedSecret
            )
        }
    }
}

extension Sequence where Element == UInt8 {
    /// return a hexEncoded string buffer from an array of bytes
    func hexDigest() -> String {
        return self.map { String(format: "%02x", $0) }.joined(separator: "")
    }
}
