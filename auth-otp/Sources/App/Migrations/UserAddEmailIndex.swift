import PostgresMigrations
import PostgresNIO

struct UserAddEmailIndex: DatabaseMigration {
    func apply(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query(
            """
            CREATE INDEX IF NOT EXISTS user_email_index 
            ON users(email)
            """,
            logger: logger
        )
    }

    func revert(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query("DROP INDEX user_email_index", logger: logger)
    }
}
