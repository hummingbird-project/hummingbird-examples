# Todos and Authentication

This is a more complete example, featuring a web page, database and user authentication.

It is a web interface for editing todos associated with a user. It implements authentication via a login page and session management. User and session details are stored in an SQLite database. Once authenticated you can create todos, list them, edit their completed state and delete them. All the webpages are generated using [Mustache](https://github.com/hummingbird-project/swift-mustache).

The first time you run this app you should run it with the `--migrate` command line parameter to ensure the database is setup.

Run the app and open up a web browser and go to http://localhost:8080

### Notes

Fluent is a database ORM developed by the Vapor team. While Vapor is also a web framework, the Fluent ORM works with any web framework including Hummingbird through the FluentKit repository.

As such, we've built [Hummingbird-Fluent](https://github.com/hummingbird-project/hummingbird-fluent) to provide a Fluent ORM for Hummingbird.