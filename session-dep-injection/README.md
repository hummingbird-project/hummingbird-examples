# Sessions without attaching everything to HBApplication

Demonstrating a simple user/session authentication setup. Using the async/await APIs of Hummingbird. The application has three routes.
- PUT /user: Creates a new user. Requires JSON input {"name": <username>, "password: <password>}
- POST /user/login: Uses Basic authentication to login user and create a session
- GET /user: Returns current user

The application uses a SQLite database accessed via `HBFluent` to store the user table, and uses the Fluent persist driver `HBFluentPersistDriver` to store sessions in `HBSessionStorage`. It has two `HBAsyncAuthenticator` middlewares. One that does the basic username/password authentication against the entries in the user database table and one that verifies the users session Cookie against the entries stored in persist. All the routes and middleware are using dependency injection instead of accessing their dependencies via `HBRequest`.

The first time you run it you should also run it with the `--migrate` command line parameter to setup the database.

This example comes with a [PAW](https://paw.cloud/) file you can use to test the various endpoints.
