import Foundation
import Hummingbird

/// A very simple model for handling requests
/// A good practice might be to extend this
/// in a way that can be stored a persistable database
/// See ``todos-fluent`` for an example of using databases
struct UploadModel: ResponseCodable {
    let filename: String
}

extension UploadModel: CustomStringConvertible {
    var description: String { self.filename }
}

extension UploadModel {
    /// Gets an appropriate `URL` to save this upload’s associated file
    /// - Parameters:
    ///   - searchPath: the preferred searchpath to save uploaded files
    ///   - allowsOverwrite: set `true` to overwrite any file with the same filename
    /// - Returns: the target directory for uploads
    func destinationURL(searchPath: FileManager.SearchPathDirectory = .documentDirectory, allowsOverwrite: Bool = false) throws -> URL {
        let fileURL = try FileManager.default.url(
            for: searchPath,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent(self.filename)

        guard allowsOverwrite == false else { return fileURL }
        guard (try? fileURL.checkResourceIsReachable()) == false else {
            throw HTTPError(.conflict)
        }
        return fileURL
    }
}
