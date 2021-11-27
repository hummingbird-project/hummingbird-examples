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
import Hummingbird
import HummingbirdFoundation

/// Handles file transfers
struct FileController {
    func addRoutes(to group: HBRouterGroup) {
        group.get(":filename", use: self.download)
        group.post("/", options: .streamBody, use: self.upload)
    }
    
    // MARK: - Upload
    
    /// Handles raw bytes by saving them to disk. Note that a good practice
    /// would be to save a reference to the bytes in a database and return
    /// that object’s ID. That way the system can locate the file later
    /// - Parameter request: `HBRequest`. If the `File-Name` header is set,
    /// then that name will be used as the file name on disk, otherwise
    /// a UUID will be used.
    /// - Returns: A JSONEncoded ``UploadModel``
    private func upload(_ request: HBRequest) async throws -> UploadModel {
        guard request.body.stream != nil else { throw HBHTTPError(.unauthorized) }
        let fileName = fileName(for: request)
        
        let uploadModel = UploadModel(filename: fileName)
        let fileURL = try uploadModel.destinationURL()
        
        request.logger.info(.init(stringLiteral: "Uploading: \(uploadModel)"))
        let fileIO = HBFileIO(application: request.application)
        try await fileIO.writeFile(contents: request.body,
                                           path: fileURL.path,
                                           context: request.context,
                                           logger: request.logger)
        return uploadModel
    }
    
    // MARK: - Download
    
    /// Downloads a file by filename.
    /// - Parameter request: any request
    /// - Returns: HBResponse of chunked bytes if success
    /// Note that this download has no login checks and allows anyone to download
    /// by its filename alone.
    private func download(_ request: HBRequest) async throws -> HBResponse {
        guard let filename = request.parameters.get("filename", as: String.self) else {
            throw HBHTTPError(.badRequest)
        }
        let uploadModel = UploadModel(filename: filename)
        let uploadURL = try uploadModel.destinationURL(allowsOverwrite: true)
        let fileIO = HBFileIO(application: request.application)
        let body = try await fileIO.loadFile(path: uploadURL.path,
                                             context: request.context,
                                             logger: request.logger)
        return HBResponse(status: .ok,
                          headers: headers(for: filename),
                          body: body)
    }
    
    
    /// Adds headers for a given filename
    /// IDEA: this is a good place to set the "Content-Type" property
    private func headers(for filename: String) -> HTTPHeaders {
        return HTTPHeaders([
            ("Content-Disposition: attachment", "filename=\"\(filename)\"")
        ])
    }
}

// MARK: - File Naming
extension FileController {
    private func uuidFileName(_ ext: String = "") -> String {
        return UUID().uuidString.appending(ext)
    }
    
    private func fileName(for request: HBRequest) -> String {
        guard let fileName = request.headers["File-Name"].first else {
            return uuidFileName()
        }
        return fileName
    }
}
