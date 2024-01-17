import Hummingbird

func buildApplication(configuration: HBApplicationConfiguration) -> some HBApplicationProtocol {
    let router = HBRouter()
    router.get("/") { _, _ in
        return "Hello"
    }

    let app = HBApplication(
        router: router,
        configuration: configuration
    )
    return app
}
