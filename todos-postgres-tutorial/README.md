# Todos Postgres Tutorial

This is the sample code that goes along with the Postgres Todos [tutorial](https://hummingbird-project.github.io/hummingbird-docs/2.0/tutorials/todos) in the documentation. The application has six routes

- GET /todos: Lists all the todos in the database
- POST /todos: Creates a new todo
- DELETE /todos: Deletes all the todos
- GET /todos/:id : Returns a single todo with id
- PATCH /todos/:id : Edits todo with id
- DELETE /todos/:id : Deletes todo with id

A todo consists of a title, order number, url to link to edit/get/delete that todo and whether that todo is complete or not.

The example requires a postgres database running locally. Follow [instructions](https://hummingbird-project.github.io/hummingbird-docs/2.0/tutorials/hummingbird/todos-4-postgres) in the tutorial to set this up.