import Hummingbird

func runApp(_ arguments: HummingbirdArguments) {
    let app = HBApplication(configuration: .init(address: .hostname(arguments.hostname, port: arguments.port)))
    app.decoder = RequestDecoder()
    app.mustache = .init(directory: "templates", logger: app.logger)
    assert(app.mustache.getTemplate(named: "head") != nil, "Set your working directory to the root folder of this example to get it to work")

    let webController = WebController()
    app.router.get("/", use: webController.input)
    app.router.post("/", use: webController.post)

    app.start()
    app.wait()
}
