# Sessions with Persist using Async/Await

Demonstrating a simple user/session authentication setup. Using the async/await APIs of Hummingbird. The application has three routes.
- PUT /user: Creates a new user. Requires JSON input {"name": <username>, "password: <password>}
- POST /user/login: Uses Basic authentication to login user and create a session
- GET /user: Returns current user

The application uses a SQLite database accessed via Fluent to store the user table, and the `HBApplication.persist` framework. It has two `HBAsyncAuthenticator` middlewares. One that does the basic username/password authentication against the entries in the user database table and one that verifies the users session Cookie against the entries stored in persist.

The first time you run it you should also run it with the `--migrate` command line parameter to setup the database.

This example comes with a [PAW](https://paw.cloud/) file you can use to test the various endpoints.
