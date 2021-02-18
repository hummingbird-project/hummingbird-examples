# Sessions with Fluent

Demonstrating a simple user/session authentication setup. The application has three routes. 
- PUT /user: Creates a new user. Requires JSON input {"name": <username>, "password: <password>}
- POST /user/login: Uses Basic authentication to login user and create a session
- GET /user: Returns current user

The application uses a SQLite database accessed via Fluent. It has two `HBAuthenticator` middlewares. One that does the basic username/password authentication against the entries in the user database table and one that verifies the users session Cookie against the entries in the session database table. 
