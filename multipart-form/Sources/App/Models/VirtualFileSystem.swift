import Hummingbird

actor VirtualFileSystem {
    var files: [String: File]

    init() {
        self.files = [:]
    }

    func save(filename: String, contents: File) {
        self.files[filename] = contents
    }

    func load(filename: String) -> File? {
        self.files[filename]
    }
}
