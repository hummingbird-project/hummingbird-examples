# Todos DynamoDB

This is an implementation of the [TodoBackend](http://www.todobackend.com/) API using DynamoDB to store the todo data. It has six routes

- GET /todos: Lists all the todos in the database
- POST /todos: Creates a new todo
- DELETE /todos: Deletes all the todos
- GET /todos/:id : Returns a single todo with id
- PATCH /todos/:id : Edits todo with id
- DELETE /todos/:id : Deletes todo with id

A todo consists of a title, order number, url to link to edit/get/delete that todo and whether that todo is complete or not.

This example does not create the DynamoDB table it uses, so you should go into the AWS console before running it and create a table with the name "hummingbird-todos" in the eu-west-1 region, with primary key set to "id" and type string.

This example comes with a [PAW](https://paw.cloud/) file you can use to test the various endpoints.
