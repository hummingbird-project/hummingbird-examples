import PostgresMigrations
import PostgresNIO

struct CreateTOTPTable: DatabaseMigration {
    func apply(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query(
            """
            CREATE TABLE IF NOT EXISTS totp (
                "user_id" uuid PRIMARY KEY,
                "secret" text NOT NULL
            )
            """,
            logger: logger
        )
    }

    func revert(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query(
            "DROP TABLE totp",
            logger: logger
        )
    }
}