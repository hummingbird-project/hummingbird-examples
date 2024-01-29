# Todos Lambda

This is an implementation of the [TodoBackend](http://www.todobackend.com/) API using HummingbirdLambda to run on an AWS Lambda. It uses DynamoDB to store the todo data. It has six routes

- GET /todos: Lists all the todos in the database
- POST /todos: Creates a new todo
- DELETE /todos: Deletes all the todos
- GET /todos/:id : Returns a single todo with id
- PATCH /todos/:id : Edits todo with id
- DELETE /todos/:id : Deletes todo with id

A todo consists of a title, order number, url to link to edit/get/delete that todo and whether that todo is complete or not.

To test this example you will need an AWS account. The example uses AWS SAM to deploy the lambda, create the DynamoDB table and APIGateway for accessing the lambda API. Installation details for AWS SAM can be found in https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html. In the scripts folder there are scripts `build-and-package.sh` to build your lambda, and `deploy.sh` to deploy it to AWS.

This example comes with a [PAW](https://paw.cloud/) file you can use to test the various endpoints. You will need to edit the development environment to update the host URL to point to your lambda.
