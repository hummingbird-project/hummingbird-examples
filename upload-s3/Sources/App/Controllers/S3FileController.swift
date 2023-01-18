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
import Hummingbird
import HummingbirdCore
import NIOHTTP1
import SotoS3

/// Handles file transfers
struct S3FileController {
    let s3: S3
    let bucket: String
    let folder: String

    func addRoutes(to group: HBRouterGroup) {
        group.get(":filename", use: self.download)
        group.post("/", options: .streamBody, use: self.upload)
    }

    // MARK: - Upload

    /// A very simple model for handling requests
    /// A good practice might be to extend this
    /// in a way that can be stored a persistable database
    /// See ``todos-fluent`` for an example of using databases
    struct UploadModel: HBResponseCodable {
        let filename: String
    }

    /// Handles raw bytes by saving them to S3 bucket.
    ///
    /// - Parameter request: `HBRequest`. If the `File-Name` header is set,
    /// then that name will be used as the file name on disk, otherwise
    /// a UUID will be used.
    /// - Returns: A JSON encoded ``UploadModel``
    private func upload(_ request: HBRequest) async throws -> UploadModel {
        guard let stream = request.body.stream else { throw HBHTTPError(.badRequest) }
        guard let contentLength: Int = request.headers["content-length"].first.map({ Int($0) }) ?? nil else {
            throw HBHTTPError(.badRequest)
        }
        let filename = fileName(for: request)

        request.logger.info(.init(stringLiteral: "Uploading: \(filename), size: \(contentLength)"))
        let body: AWSPayload = .stream(size: contentLength) { eventLoop in
            return stream.consume(on: eventLoop).map { output in
                switch output {
                case .byteBuffer(let buffer):
                    return .byteBuffer(buffer)
                case .end:
                    return .end
                }
            }
        }
        let putObjectRequest = S3.PutObjectRequest(
            body: body,
            bucket: self.bucket,
            contentType: request.headers["content-type"].first,
            key: "\(self.folder)/\(filename)"
        )
        do {
            _ = try await self.s3.putObject(putObjectRequest, logger: request.logger, on: request.eventLoop)
            return UploadModel(filename: filename)
        } catch {
            throw HBHTTPError(.internalServerError)
        }
    }

    // MARK: - Download

    /// Downloads a file by filename from S3.
    ///
    /// - Parameter request: any request
    /// - Returns: HBResponse of chunked bytes if success
    /// Note that this download has no login checks and allows anyone to download
    /// by its filename alone.
    private func download(request: HBRequest) async throws -> HBResponse {
        guard let filename = request.parameters.get("filename", as: String.self) else {
            throw HBHTTPError(.badRequest)
        }
        // due to the fact that `getObjectStreaming` doesn't return until all data is downloaded we have
        // to get headers values via a headObject call first
        let key = "\(self.folder)/\(filename)"
        let headResponse = try await s3.headObject(
            .init(bucket: self.bucket, key: key),
            logger: request.logger,
            on: request.eventLoop
        )
        var headers = HTTPHeaders()
        if let contentLength = headResponse.contentLength {
            headers.add(name: "content-length", value: contentLength.description)
        }
        if let contentType = headResponse.contentType {
            headers.add(name: "content-type", value: contentType)
        }
        // create response body streamer
        let streamer = HBByteBufferStreamer(
            eventLoop: request.eventLoop,
            maxSize: 2048 * 1024,
            maxStreamingBufferSize: 128 * 1024
        )
        // run streaming task separate from request. This means we can start passing buffers from S3 back to
        // the client immediately
        Task {
            _ = try await s3.getObjectStreaming(
                .init(bucket: self.bucket, key: key),
                logger: request.logger,
                on: request.eventLoop
            ) { buffer, _ in
                return streamer.feed(buffer: buffer)
            }
            streamer.feed(.end)
        }
        return HBResponse(
            status: .ok,
            headers: headers,
            body: .stream(streamer)
        )
    }
}

// MARK: - File Naming

extension S3FileController {
    private func uuidFileName(_ ext: String = "") -> String {
        return UUID().uuidString.appending(ext)
    }

    private func fileName(for request: HBRequest) -> String {
        guard let fileName = request.headers["File-Name"].first else {
            return self.uuidFileName()
        }
        return fileName
    }
}
