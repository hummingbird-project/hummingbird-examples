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

import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdFoundation

/// Handles file transfers
struct FileController {
    let fileIO = HBFileIO()

    func addRoutes(to group: HBRouterGroup<some HBRequestContext>) {
        group.get(":filename", use: self.download)
        group.post("/", use: self.upload)
    }

    // MARK: - Upload

    /// Handles raw bytes by saving them to disk. Note that a good practice
    /// would be to save a reference to the bytes in a database and return
    /// that object’s ID. That way the system can locate the file later or
    /// store any associated metadata like `Content-Type` or authorization
    /// data.
    /// - Parameter request: `HBRequest`. If the `File-Name` header is set,
    /// then that name will be used as the file name on disk, otherwise
    /// a UUID will be used.
    /// - Returns: A JSONEncoded ``UploadModel``
    @Sendable private func upload(_ request: HBRequest, context: some HBRequestContext) async throws -> UploadModel {
        let fileName = fileName(for: request)

        let uploadModel = UploadModel(filename: fileName)
        let fileURL = try uploadModel.destinationURL()

        context.logger.info(.init(stringLiteral: "Uploading: \(uploadModel)"))
        try await self.fileIO.writeFile(
            contents: request.body,
            path: fileURL.path,
            context: context
        )
        return uploadModel
    }

    // MARK: - Download

    /// Downloads a file by filename.
    /// - Parameter request: any request
    /// - Returns: HBResponse of chunked bytes if success
    /// Note that this download has no login checks and allows anyone to download
    /// by its filename alone.
    @Sendable private func download(_ request: HBRequest, context: some HBRequestContext) async throws -> HBResponse {
        let filename = try context.parameters.require("filename", as: String.self)
        let uploadModel = UploadModel(filename: filename)
        let uploadURL = try uploadModel.destinationURL(allowsOverwrite: true)
        let body = try await self.fileIO.loadFile(
            path: uploadURL.path,
            context: context
        )
        return HBResponse(
            status: .ok,
            headers: self.headers(for: filename),
            body: body
        )
    }

    /// Adds headers for a given filename
    /// IDEA: this is a good place to set the "Content-Type" property
    private func headers(for filename: String) -> HTTPFields {
        return [
            .contentDisposition: "attachment;filename=\"\(filename)\"",
        ]
    }
}

// MARK: - File Naming

extension FileController {
    private func uuidFileName(_ ext: String = "") -> String {
        return UUID().uuidString.appending(ext)
    }

    private func fileName(for request: HBRequest) -> String {
        guard let fileName = request.headers[.fileName] else {
            return self.uuidFileName()
        }
        return fileName
    }
}

extension HTTPField.Name {
    static var fileName: Self { .init("File-Name")! }
}
