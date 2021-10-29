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

struct UploadController {
    func addRoutes(to group: HBRouterGroup) {
        group.post("/", options: .streamBody, use: self.upload)
    }
    
    private func upload(_ request: HBRequest) async throws -> String {
        guard request.body.stream != nil else { throw HBHTTPError(.unauthorized) }
        let fileName = fileName(for: request)
        let fileURL = try destinationPath(for: fileName, allowsOverwrite: true)
        request.logger.info(.init(stringLiteral: "Uploading: \(fileURL)"))
        let handled = try await request.fileIO.writeFile(contents: request.body,
                                                         path: fileURL.path,
                                                         context: request.context,
                                                         logger: request.logger)
            .transform(to: "Uploaded as \(fileName)")
            .get()
        return handled
    }
    
    private var tempDirectory: URL = FileManager.default.temporaryDirectory
}

// MARK: - File Management
extension UploadController {
    private func uuidFileName(_ ext: String = ".txt") -> String {
        return UUID().uuidString.appending(ext)
    }
    
    private func fileName(for request: HBRequest) -> String {
        guard let fileName = request.headers["File-Name"].first else {
            return uuidFileName()
        }
        return fileName
    }
    
    private func destinationPath(for fileName: String, allowsOverwrite: Bool = false) throws -> URL {
        let filePath = tempDirectory.appendingPathComponent(fileName)
        guard allowsOverwrite == false else { return filePath }
        guard FileManager.default.fileExists(atPath: filePath.path) == false else {
            throw HBHTTPError(.conflict)
        }
        return filePath
    }
}
