# todos-postgres

This is an implementation of the [TodoBackend](http://www.todobackend.com/) using the async/await APIs from [PostgresNIO](https://github.com/vapor/postgres-nio). Before you start you need access to a PostgreSQL database running on `localhost:5432` called `hummingbird` with a user `hummingbird` and password `hb-password`. You can change these details in [Application+configure.swift](Sources/App/Application+configure.swift). 

The application has six routes. 

- GET /todos: Lists all the todos in the database
- POST /todos: Creates a new todo
- DELETE /todos: Deletes all the todos
- GET /todos/:id : Returns a single todo with id
- PATCH /todos/:id : Edits todo with id
- DELETE /todos/:id : Deletes todo with id

A todo consists of a title, order number, url to link to edit/get/delete that todo and whether that todo is complete or not.

This example comes with a [PAW](https://paw.cloud/) file you can use to test the various endpoints.
