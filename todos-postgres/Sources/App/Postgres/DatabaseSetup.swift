import Hummingbird

extension HBApplication {
    func setupDatabase() async throws {
        let eventLoop = self.eventLoopGroup.next();
        let pool = self.postgresConnectionGroup.getConnectionPool(on: eventLoop);
        try await pool.lease(logger: self.logger) { connection in
            // get list of tables
            let tables = try await connection.query("""
                SELECT tablename FROM pg_catalog.pg_tables 
                WHERE schemaname != 'pg_catalog' 
                AND schemaname != 'information_schema';
                """, logger: self.logger
            )
            // if "todospostgres" table exists already return
            for try await (tablename) in tables.decode(String.self, context: .default) {
                if tablename == "todospostgres" {
                    return
                }
            }

            // create table
            try await connection.query("""
                CREATE TABLE todospostgres (
                    "id" uuid PRIMARY KEY,
                    "title" text NOT NULL,
                    "order" integer,
                    "completed" boolean,
                    "url" text
                );
                """, logger: self.logger
            )
        }
    }
}