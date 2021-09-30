import Hummingbird
import HummingbirdMustache
import MultipartKit

extension HBApplication {
    /// configure your application
    /// add middleware
    /// setup the encoder/decoder
    /// add your routes
    public func configure() throws {
        self.decoder = RequestDecoder()

        let library = try HBMustacheLibrary(directory: "templates")
        assert(library.getTemplate(named: "head") != nil, "Set your working directory to the root folder of this example to get it to work")

        let webController = WebController(mustacheLibrary: library)
        self.router.get("/", use: webController.input)
        self.router.post("/", use: webController.post)
    }
}
