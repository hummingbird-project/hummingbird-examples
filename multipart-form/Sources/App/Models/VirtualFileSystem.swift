import Hummingbird

/// An actor representing a virtual file system that can store and retrieve files.
actor VirtualFileSystem {
    /// A dictionary to store files, where the key is the filename and the value is the `File` object.
    var files: [String: File]

    /// Initializes a new instance of `VirtualFileSystem` with an empty file dictionary.
    init() {
        self.files = [:]
    }

    /// Saves a file to the virtual file system.
    ///
    /// - Parameters:
    ///   - filename: The name of the file to save.
    ///   - contents: The `File` object containing the contents of the file.
    func save(filename: String, contents: File) {
        self.files[filename] = contents
    }

    /// Loads a file from the virtual file system.
    ///
    /// - Parameter filename: The name of the file to load.
    /// - Returns: The `File` object if the file exists; otherwise, `nil`.
    func load(filename: String) -> File? {
        self.files[filename]
    }
}
