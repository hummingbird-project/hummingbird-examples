//
//  FileHelperTests.swift
//  multipart-form
//
//  Created by ian on 19/05/2025.
//

@testable import App
import Hummingbird
import HummingbirdTesting
import NIOFileSystem
import XCTest

final class FileHelperTests: XCTestCase {
    override func tearDown() async throws {
        // Clean up any created directories or files
        let contentDirectory = try await File.getContentDirectory()
        try await FileSystem.shared.removeItem(at: contentDirectory)
        try await super.tearDown()
    }

    func testGetUniqueFilePath() async throws {
        let byteBuffer = ByteBuffer(bytes: "this is a test".data(using: .utf8) ?? Data())
        let testFile = File(
            data: byteBuffer,
            filename: "test-file.txt",
            contentType: "text/plain"
        )

        let testFileRelativePath = try await testFile.saveDataToDisk()
        XCTAssertEqual(testFileRelativePath, "content/test-file.txt")
        let testFileRelativePath1 = try await testFile.saveDataToDisk()
        XCTAssertEqual(testFileRelativePath1, "content/test-file-1.txt")
        let testFileRelativePath2 = try await testFile.saveDataToDisk()
        XCTAssertEqual(testFileRelativePath2, "content/test-file-2.txt")

        let testFile2 = File(
            data: byteBuffer,
            filename: "test-file-3.txt",
            contentType: "text/plain"
        )

        let testFileRelativePath3 = try await testFile2.saveDataToDisk()
        XCTAssertEqual(testFileRelativePath3, "content/test-file-3.txt")
    }
}
