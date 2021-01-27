import Hummingbird

func runApp(_ arguments: HummingbirdArguments) {
    let app = HBApplication(configuration: .init(address: .hostname(arguments.hostname, port: arguments.port)))
    app.decoder = RequestDecoder()

    let webController = WebController()
    app.router.get("/index.html", use: webController.input)
    app.router.post("/index.html", use: webController.post)

    app.start()
    app.wait()
}
