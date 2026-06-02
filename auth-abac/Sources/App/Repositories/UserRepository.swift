import FluentKit
import Foundation
import HummingbirdAuth
import HummingbirdFluent

/// Resolves a `User` from a stored session UUID.
struct UserRepository: UserSessionRepository {
    typealias Identifier = UUID

    let fluent: Fluent

    func getUser(from id: UUID, context: UserRepositoryContext) async throws -> User? {
        try await User.find(id, on: fluent.db())
    }
}
