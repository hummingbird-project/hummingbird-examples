@testable import App
import Crypto
import HBXCTAsyncHTTPClient
import Hummingbird
import HummingbirdXCT
import NIOHTTP2
import NIOSSL
import X509
import XCTest

struct TestAppArguments: AppArguments {
    var tlsConfiguration: TLSConfiguration {
        get throws {
            let now = Date()
            let issuerKey = P256.Signing.PrivateKey()
            let issuerName = try DistinguishedName {
                CommonName("Issuer")
            }
            let leafKey = P256.Signing.PrivateKey()
            let leafName = try DistinguishedName {
                CommonName("Leaf")
            }
            let leaf = try Certificate(
                version: .v3,
                serialNumber: .init(),
                publicKey: .init(leafKey.publicKey),
                notValidBefore: now - 5000,
                notValidAfter: now + 5000,
                issuer: issuerName,
                subject: leafName,
                signatureAlgorithm: .ecdsaWithSHA256,
                extensions: Certificate.Extensions {
                    Critical(
                        BasicConstraints.notCertificateAuthority
                    )
                },
                issuerPrivateKey: .init(issuerKey)
            )
            let certificateChain = try NIOSSLCertificate.fromPEMBytes(Array(leaf.serializeAsPEM().pemString.utf8))
            var tlsConfiguration = try TLSConfiguration.makeServerConfiguration(
                certificateChain: certificateChain.map { .certificate($0) },
                privateKey: .privateKey(.init(bytes: Array(leafKey.pemRepresentation.utf8), format: NIOSSLSerializationFormats.pem))
            )
            tlsConfiguration.applicationProtocols = NIOHTTP2SupportedALPNProtocols
            return tlsConfiguration
        }
    }
}

final class AppTests: XCTestCase {
    func testApp() throws {
        var clientConfiguration = TLSConfiguration.makeClientConfiguration()
        clientConfiguration.certificateVerification = .none
        let app = HBApplication(
            testing: .ahc(scheme: .https),
            configuration: .init(idleTimeoutConfiguration: .init(readTimeout: .seconds(5), writeTimeout: .seconds(5))),
            clientConfiguration: .init(tlsConfiguration: clientConfiguration)
        )
        try app.configure(TestAppArguments())

        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/http", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.body.map { String(buffer: $0) }, "Using http v2.0")
        }

        try app.XCTExecute(uri: "/http", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.body.map { String(buffer: $0) }, "Using http v2.0")
        }
    }
}
