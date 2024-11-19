import HummingbirdBcrypt
import Foundation
import Hummingbird
import Logging
import PostgresNIO

struct UserPostgresRepository: UserRepository {
    let client: PostgresClient

    func createUser(name: String, email: String, password: String, logger: Logger) async throws -> User {
        let id = UUID()
        let passwordHash = try await NIOThreadPool.singleton.runIfActive {
            Bcrypt.hash(password)
        }
        // The string interpolation is building a PostgresQuery with bindings and is safe from sql injection
        try await self.client.query(
            "INSERT INTO users (id, name, email, password_hash) VALUES (\(id), \(name), \(email), \(passwordHash))",
            logger: logger
        )
        return User(id: id, name: name, email: email, passwordHash: passwordHash, otpSecret: nil)
    }

    func getUser(id: UUID, logger: Logger) async throws -> User? {
        let stream = try await self.client.query(
            """
            SELECT users.id, users.name, users.email, users.password_hash,
            totp.secret
            FROM users LEFT OUTER JOIN totp ON (users.id = totp.user_id)
            WHERE users.id = \(id)
            """,
            logger: logger
        )
        for try await (id, name, email, passwordHash, otpSecret) in stream.decode((UUID, String, String, String?, String?).self, context: .default) {
            return User(id: id, name: name, email: email, passwordHash: passwordHash, otpSecret: otpSecret)
        }
        return nil
    }

    func getUser(email: String, logger: Logger) async throws -> User? {
        let stream = try await self.client.query(
            """
            SELECT users.id, users.name, users.email, users.password_hash,
            totp.secret
            FROM users LEFT OUTER JOIN totp ON (users.id = totp.user_id)
            WHERE users.email = \(email)
            """,
            logger: logger
        )
        for try await (id, name, email, passwordHash, otpSecret) in stream.decode((UUID, String, String, String?, String?).self, context: .default) {
            return User(id: id, name: name, email: email, passwordHash: passwordHash, otpSecret: otpSecret)
        }
        return nil
    }

    func addTOTP(userID: UUID, secret: String, logger: Logger) async throws {
        // The string interpolation is building a PostgresQuery with bindings and is safe from sql injection
        try await self.client.query(
            "INSERT INTO totp (user_id, secret) VALUES (\(userID), \(secret))",
            logger: logger
        )
    }

    func removeTOTP(userID: UUID, logger: Logger) async throws {
        // The string interpolation is building a PostgresQuery with bindings and is safe from sql injection
        try await self.client.query(
            "DELETE FROM totp WHERE user_id = \(userID)",
            logger: logger
        )
    }
}