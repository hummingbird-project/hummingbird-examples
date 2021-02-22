import Hummingbird
import HummingbirdFoundation

func runApp(_ arguments: HummingbirdArguments) {
    let app = HBApplication(configuration: .init(address: .hostname(arguments.hostname, port: arguments.port)))
    app.middleware.add(HBFileMiddleware(application: app))
    app.router.get("/") { _ in
        return "Hello"
    }
    app.start()
    app.wait()
}
