import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdBasicAuth
import Logging

protocol UserRepository: Sendable, UserPasswordRepository, UserSessionRepository where User == App.User, Identifier == App.Session {
    func createUser(name: String, email: String, password: String, logger: Logger) async throws -> User
    func getUser(id: UUID, logger: Logger) async throws -> User?
    func getUser(email: String, logger: Logger) async throws -> User?
    func addTOTP(userID: UUID, secret: String, logger: Logger) async throws
    func removeTOTP(userID: UUID, logger: Logger) async throws
}

extension UserRepository {
    // required by protocol UserPasswordRepository
    func getUser(named username: String, context: UserRepositoryContext) async throws -> User? {
        try await getUser(email: username, logger: context.logger)
    }
    // required by protocol UserSessionRepository
    func getUser(from session: Identifier, context: UserRepositoryContext) async throws -> User? {
        switch session {
        case .authenticated(let userID):
            try await getUser(id: userID, logger: context.logger)
        default:
            nil
        }
    }
}