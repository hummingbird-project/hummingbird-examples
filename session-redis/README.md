# Sessions with Redis

Demonstrating a simple user/session authentication setup. The application has three routes. 
- PUT /user: Creates a new user. Requires JSON input {"name": <username>, "password: <password>}
- POST /user/login: Uses Basic authentication to login user and create a session
- GET /user: Returns current user

The application uses a SQLite database accessed via Fluent to store the user table, and a Redis instance to store the session tokens. It has two `HBAuthenticator` middlewares. One that does the basic username/password authentication against the entries in the user database table and one that verifies the users session Cookie against the entries in the redis instance.

For this example to work you need a running Redis instance.
```
docker run -p 6379:6379 redis
```
