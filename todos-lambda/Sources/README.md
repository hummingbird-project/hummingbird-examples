# Todos Lambda

This is an implementation of the [TodoBackend](http://www.todobackend.com/) API using DynamoDB to store the todo data and running on AWS Lambda. The application has six routes

- GET /todos: Lists all the todos in the database
- POST /todos: Creates a new todo
- DELETE /todos: Deletes all the todos
- GET /todos/:id : Returns a single todo with id
- PATCH /todos/:id : Edits todo with id
- DELETE /todos/:id : Deletes todo with id

A todo consists of a title, order number, url to link to edit/get/delete that todo and whether that todo is complete or not.

To install run `./scripts/install.sh`, then go to your AWS console and create a new REST based APIGateway and import `TodoBackend-APIGateway-swagger.json`. You will need to link up each method to your Lambda. Select the method, ensure `Use Lambda Proxy integration` has a tick and then type the name of your Lambda function in the `Lambda Function` text field. Remember to do this for the `OPTIONS` routes as well.

