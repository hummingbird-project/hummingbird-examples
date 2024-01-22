# Todos MongoKitten OpenAPI

This is an implementation of an API using an OpenAPI specification. The API uses a MongoDB database accessed via MongoKitten to store the todo data.

This API has four routes:

- GET /todos: Lists all the todos in the database
- POST /todos: Creates a new todo
- GET /todos/:id : Returns a single todo with id
- PUT /todos/:id : Overwrite properties of a todo with id

A todo consists of an array called `items`, containing the tasks that you still need to do.

This example comes with a [PAW](https://paw.cloud/) file you can use to test the various endpoints.