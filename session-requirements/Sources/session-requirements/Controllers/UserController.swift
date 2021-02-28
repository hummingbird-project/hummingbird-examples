import FluentKit
import Foundation
import Hummingbird
import HummingbirdRequirements
import NIO

struct UserController {
    /// Add routes for user controller
    func addRoutes(to group: HBRouterGroup) {
        group.put(use: create)
        group.group("login").add(middleware: BasicAuthenticator())
            .post(use: login)
        group.add(middleware: SessionAuthenticator())
            .get(use: current)
    }

    /// Create new user
    struct CreateReq: HBRouteRequirements {
        @HBReqDecoded var createUserRequest: CreateUserRequest
        @HBReqRequest(\.db) var db
    }
    func create(_ request: CreateReq) -> EventLoopFuture<UserResponse> {
        let user = User(from: request.createUserRequest)
        // check if user exists and if they don't then add new user
        return User.query(on: request.db)
            .filter(\.$name == user.name)
            .first()
            .flatMapThrowing { user -> Void in
                // if user already exist throw conflict
                guard user == nil else { throw HBHTTPError(.conflict) }
                return
            }
            .flatMap { _ in
                return user.save(on: request.db)
            }
            .transform(to: UserResponse(from: user))
    }

    /// Login user and create session
    struct LoginReq: HBRouteRequirements {
        @HBReqRequest(\.auth) var auth
        @HBReqRequest(\.session) var session
        @HBReqEventLoop var eventLoop
    }
    func login(_ request: LoginReq) -> EventLoopFuture<HTTPResponseStatus> {
        // get authenticated user and return
        guard let user = request.auth.get(User.self),
              let userId = user.id else { return request.eventLoop.makeFailedFuture(HBHTTPError(.unauthorized)) }
        return request.session.save(userId: userId, expiresIn: .hours(1)).map { .ok }
    }

    /// Get current logged in user
    struct CurrentReq: HBRouteRequirements {
        @HBReqRequest(\.auth) var auth
    }
    func current(_ request: CurrentReq) throws -> UserResponse {
        // get authenticated user and return
        guard let user = request.auth.get(User.self) else { throw HBHTTPError(.unauthorized) }
        return UserResponse(from: user)
    }
}
