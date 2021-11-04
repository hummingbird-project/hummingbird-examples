import Hummingbird
import HummingbirdFoundation

extension HBApplication {
    public func configure() throws {
        let uploadController = UploadController()
        uploadController.addRoutes(to: self.router.group("upload"))
    }
}
