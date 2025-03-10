# Auth Token (JWT)

This example shows you how to generate a JWT for a user to be used later as an authentication token.

## Usage

Before you can generate a JWT you have to authenticate using some other method. This example includes a basic
authentication path for logging in a user with a password which then returns a JWT.

- Users are created with the route PUT /user. The body for this request should be JSON and include a `name` and `password` 
field. 
- Login (POST /user) uses basic authentication and its response will include a JSON body with the JWT token in a 
`token` field. This token can then be used to add id authentication to any route.

The first time you run the app you should include the `--migrate` command line parameter to setup the database.

This example comes with a [PAW](https://paw.cloud/) file you can use to test the various endpoints.
