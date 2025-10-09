import PostgresMigrations
import PostgresNIO

struct CreateUserTable: DatabaseMigration {
    func apply(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query(
            """
            CREATE TABLE IF NOT EXISTS users (
                "id" uuid PRIMARY KEY,
                "name" text NOT NULL,
                "email" text NOT NULL,
                "password_hash" text 
            )
            """,
            logger: logger
        )
    }

    func revert(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query(
            "DROP TABLE users",
            logger: logger
        )
    }
}
