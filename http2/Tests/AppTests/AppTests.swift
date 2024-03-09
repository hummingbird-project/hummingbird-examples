@testable import App
import Crypto
import Hummingbird
import HummingbirdTesting
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
    func testApp() async throws {
        let app = try buildApplication(arguments: TestAppArguments(), configuration: .init())

        try await app.test(.ahc(.https)) { client in
            try await client.execute(uri: "/http", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(String(buffer: response.body), "Using http v2.0")
            }

            try await client.execute(uri: "/http", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(String(buffer: response.body), "Using http v2.0")
            }
        }
    }
}
