import Hummingbird

extension HBApplication {
    /// configure your application
    /// add middleware
    /// setup the encoder/decoder
    /// add your routes
    public func configure() throws {
        self.decoder = RequestDecoder()
        self.mustache = try .init(directory: "templates")
        assert(self.mustache.getTemplate(named: "head") != nil, "Set your working directory to the root folder of this example to get it to work")

        let webController = WebController()
        self.router.get("/", use: webController.input)
        self.router.post("/", use: webController.post)
    }
}
