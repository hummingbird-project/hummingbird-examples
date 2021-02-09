import FluentKit
import Foundation
import Hummingbird
import NIO

struct UserController {
    /// Add routes for user controller
    func addRoutes(to group: HBRouterGroup) {
        group
            .put(use: create)
            .group()
                .add(middleware: BasicAuthenticator())
                .get(use: current)
    }

    /// Create new user
    func create(_ request: HBRequest) -> EventLoopFuture<UserResponse> {
        guard let createUser = try? request.decode(as: CreateUserRequest.self) else { return request.failure(.badRequest) }
        let user = User(from: createUser)
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
    
    func current(_ request: HBRequest) throws -> UserResponse {
        // get authenticated user and return
        guard let user = request.auth.get(User.self) else { throw HBHTTPError(.unauthorized) }
        return UserResponse(from: user)
    }
}
