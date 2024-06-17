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

import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdCore
import SotoS3

/// Handles file transfers
struct S3FileController {
    let s3: S3
    let bucket: String
    let folder: String

    func getRoutes<Context: RequestContext>(context: Context.Type = Context.self) -> RouteCollection<Context> {
        return RouteCollection(context: Context.self)
            .get(":filename", use: self.download)
            .post("/", use: self.upload)
    }

    // MARK: - Upload

    /// A very simple model for handling requests
    /// A good practice might be to extend this
    /// in a way that can be stored a persistable database
    /// See ``todos-fluent`` for an example of using databases
    struct UploadModel: ResponseCodable {
        let filename: String
    }

    /// Handles raw bytes by saving them to S3 bucket.
    ///
    /// - Parameter request: `HBRequest`. If the `File-Name` header is set,
    /// then that name will be used as the file name on disk, otherwise
    /// a UUID will be used.
    /// - Returns: A JSON encoded ``UploadModel``
    @Sendable private func upload(_ request: Request, context: some RequestContext) async throws -> UploadModel {
        guard let contentLength: Int = (request.headers[.contentLength].map { Int($0) } ?? nil) else {
            throw HTTPError(.badRequest)
        }
        let filename = fileName(for: request)

        context.logger.info(.init(stringLiteral: "Uploading: \(filename), size: \(contentLength)"))
        let putObjectRequest = S3.PutObjectRequest(
            body: .init(asyncSequence: request.body, length: contentLength),
            bucket: self.bucket,
            contentType: request.headers[.contentType],
            key: "\(self.folder)/\(filename)"
        )
        do {
            _ = try await self.s3.putObject(putObjectRequest, logger: context.logger)
            return UploadModel(filename: filename)
        } catch {
            throw HTTPError(.internalServerError)
        }
    }

    // MARK: - Download

    /// Downloads a file by filename from S3.
    ///
    /// - Parameter request: any request
    /// - Returns: HBResponse of chunked bytes if success
    /// Note that this download has no login checks and allows anyone to download
    /// by its filename alone.
    @Sendable private func download(request: Request, context: some RequestContext) async throws -> Response {
        guard let filename = context.parameters.get("filename") else {
            throw HTTPError(.badRequest)
        }
        // due to the fact that `getObjectStreaming` doesn't return until all data is downloaded we have
        // to get headers values via a headObject call first
        let key = "\(self.folder)/\(filename)"
        let s3Response = try await self.s3.getObject(
            .init(bucket: self.bucket, key: key),
            logger: context.logger
        )
        var headers = HTTPFields()
        if let contentLength = s3Response.contentLength {
            headers[.contentLength] = contentLength.description
        }
        if let contentType = s3Response.contentType {
            headers[.contentType] = contentType
        }
        return Response(
            status: .ok,
            headers: headers,
            body: .init(asyncSequence: s3Response.body)
        )
    }
}

// MARK: - File Naming

extension S3FileController {
    private func uuidFileName(_ ext: String = "") -> String {
        return UUID().uuidString.appending(ext)
    }

    private func fileName(for request: Request) -> String {
        guard let fileName = request.headers[.fileName] else {
            return self.uuidFileName()
        }
        return fileName
    }
}

extension HTTPField.Name {
    static var fileName: Self { .init("File-Name")! }
}
