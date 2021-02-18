import Hummingbird

func runApp(_ arguments: HummingbirdArguments) {
    let app = HBApplication(configuration: .init(address: .hostname(arguments.hostname, port: arguments.port)))
    app.decoder = RequestDecoder()

    let webController = WebController()
    app.router.get("/", use: webController.input)
    app.router.post("/", use: webController.post)

    app.start()
    app.wait()
}
