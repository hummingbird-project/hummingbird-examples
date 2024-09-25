import Hummingbird
import HummingbirdAuth
import Mustache

struct WebController<Users: UserRepository, Storage: PersistDriver> {
    let mustacheLibrary: MustacheLibrary
    let indexTemplate: MustacheTemplate
    let users: Users
    let storage: Storage

    init(
        mustacheLibrary: MustacheLibrary,
        users: Users,
        storage: Storage
    ) {
        self.mustacheLibrary = mustacheLibrary
        self.users = users
        self.storage = storage

        self.indexTemplate = mustacheLibrary.getTemplate(named: "index")!
    }

    var endpoints: RouteCollection<AppRequestContext> {
        let routes = RouteCollection(context: AppRequestContext.self)
        routes.group("", context: AppSessionRequestContext.self)
            .addMiddleware {
                SessionMiddleware(storage: self.storage)
                SessionAuthenticator(users: users)
                RedirectMiddleware(to: "/login.html")
            }
            .get { _, context in
                let user = try context.auth.require(User.self)
                let context: [String: Any] = [
                    "name": user.name, 
                    "addOTP": user.otpSecret == nil
                ]
                return HTML(self.indexTemplate.render(context, library: self.mustacheLibrary))
            }
        return routes
    }
}
