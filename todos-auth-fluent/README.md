# Todos and Authentication

This is a more complete example. It is a web interface for editing todos associated with a user. It implements authentication via a login page and session management. User and session details are stored in an SQLite database. Once authenticated you can create todos, list them, edit their completed state and delete them. All the webpages are generated using mustache.

The first time you run this app you should run it with the `--migrate` command line parameter to ensure the database is setup.

Run the app and open up a web browser and go to localhost:8080. 