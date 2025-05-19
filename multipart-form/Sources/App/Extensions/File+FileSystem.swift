import NIOFileSystem

// MARK: - Save File to Disk

extension File {
    @discardableResult
    public func saveDataToDisk() async throws -> FilePath {
        let (fullFilePath, relativeFilePath) = try await File.getDiskFilePath(using: self.filename)
        let fileHandle = try await FileSystem.shared.openFile(
            forWritingAt: fullFilePath,
            options: .newFile(replaceExisting: true)
        )
        try await fileHandle.write(contentsOf: self.data, toAbsoluteOffset: 0)
        try await fileHandle.close(makeChangesVisible: true)
        return relativeFilePath
    }
}

// MARK: - Helper Functions

extension File {
    static public func getPublicDirectory() async throws -> FilePath {
        let workingDirectory = try await FileSystem.shared.currentWorkingDirectory
        let publicDirectory = workingDirectory.appending("public")
        try? await FileSystem.shared.createDirectory(at: publicDirectory, withIntermediateDirectories: true)
        return publicDirectory
    }

    static public func getContentDirectory() async throws -> FilePath {
        let publicDirectory = try await getPublicDirectory()
        let contentDirectory = publicDirectory.appending("content")
        try? await FileSystem.shared.createDirectory(at: contentDirectory, withIntermediateDirectories: true)
        return contentDirectory
    }

    static public func getDiskFilePath(using filename: String) async throws -> (
        fullFilePath: FilePath,
        relativeFilePath: FilePath
    ) {
        let publicDirectory = try await getPublicDirectory()
        let contentDirectory = try await getContentDirectory()
        let urlSafeFilename = getURLSafeFilename(using: filename)
        let fullFilePath = try await getUniqueFilePath(using: contentDirectory.appending(urlSafeFilename))
        var relativeFilePath = fullFilePath
        if relativeFilePath.removePrefix(publicDirectory) == false {
            relativeFilePath = FilePath(fullFilePath.string.replacing(publicDirectory.string, with: ""))
        }
        return (fullFilePath, relativeFilePath)
    }

    static public func getUniqueFilePath(using filePath: FilePath) async throws -> FilePath {
        guard let stem = filePath.stem else {
            return filePath
        }
        // Check if file exists
        // if exists add a number to the stem (filename without extension)
        if try await FileSystem.shared.fileExists(at: filePath) {
            let stemIntegerPart = Int(String(stem.split(separator: "-").last ?? "0")) ?? 0
            let uniqueStem: String
            if stemIntegerPart == 0 {
                uniqueStem = stem.appending("-").appending("1")
            } else {
                uniqueStem = stem.replacing("-\(stemIntegerPart)", with: "-\(stemIntegerPart + 1)")
            }
            let newFilePath = FilePath(filePath.string.replacing(stem, with: uniqueStem))
            return try await getUniqueFilePath(using: newFilePath)
        } else {
            return filePath
        }
    }

    static public func getURLSafeFilename(using filename: String) -> String {
        var urlSafeFileName = filename.replacingOccurrences(of: " ", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        urlSafeFileName = urlSafeFileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? urlSafeFileName
        return urlSafeFileName
    }
}

extension FileSystem {
    fileprivate func fileExists(at path: FilePath) async throws -> Bool {
        try await self.info(forFileAt: path) != nil
    }
}
