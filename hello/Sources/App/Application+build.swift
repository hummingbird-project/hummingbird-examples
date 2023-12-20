import Hummingbird

func buildApplication(configuration: HBApplicationConfiguration) -> some HBApplicationProtocol {
    let router = HBRouter()
    router.get("/") { _, _ in
        return "Hello"
    }

    let app = HBApplication(
        responder: router.buildResponder(),
        configuration: configuration
    )
    return app
}
