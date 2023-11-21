import Hummingbird
import HummingbirdCore
import HummingbirdFoundation

func buildApplication(configuration: HBApplicationConfiguration) -> HBApplication<some HBResponder<HBBasicRequestContext>, HTTP1Channel> {
    let router = HBRouterBuilder()
    router.middlewares.add(HBFileMiddleware())
    router.get("/") { _, _ in
        return "Hello"
    }

    let app = HBApplication(
        responder: router.buildResponder(),
        configuration: configuration
    )
    return app
}
