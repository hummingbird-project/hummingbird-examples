import Hummingbird
import HummingbirdAuth
import HummingbirdBasicAuth

struct UserController<Users: UserRepository, Storage: PersistDriver>: Sendable {
    let users: Users
    let storage: Storage

    var endpoints: RouteCollection<AppRequestContext> {
        let routes = RouteCollection(context: AppRequestContext.self)
        let group = routes.group("users")
            .put(use: self.createUser)
        group.group("", context: AppSessionRequestContext.self)
            .addMiddleware {
                SessionMiddleware(storage: self.storage)
                BasicAuthenticator(users: self.users)
                TOTPAuthenticator(users: self.users)
            }
            .post { _, context in
                let user = try context.auth.require(User.self)
                let session = context.sessions.session
                if user.otpSecret != nil {
                    switch session {
                    case .challenge:
                        return Response(status: .unauthorized, headers: [.challenge: "totp"])
                    case .authenticated:
                        return Response(status: .ok)
                    case .none:
                        context.sessions.setSession(.challenge(.totp(user.id)), expiresIn: .seconds(60 * 60 * 24))
                        return Response(status: .unauthorized, headers: [.challenge: "totp"])
                    }
                } else {
                    context.sessions.setSession(.authenticated(user.id), expiresIn: .seconds(60 * 60 * 24))
                }
                return Response(status: .ok)
            }
        group.group("", context: AppSessionRequestContext.self)
            .addMiddleware {
                SessionMiddleware(storage: self.storage)
                SessionAuthenticator(users: self.users)
            }
            .post("logout") { _, context in
                context.sessions.clearSession()
                return HTTPResponse.Status.ok
            }
        return routes
    }

    struct CreateUserRequest: Decodable {
        let name: String
        let email: String
        let password: String
    }

    @Sendable func createUser(request: Request, context: some RequestContext) async throws -> HTTPResponse.Status {
        let createUser = try await request.decode(as: CreateUserRequest.self, context: context)
        _ = try await self.users.createUser(
            name: createUser.name,
            email: createUser.email,
            password: createUser.password,
            logger: context.logger
        )
        return .ok
    }
}
