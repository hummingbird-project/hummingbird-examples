# Auth Token (JWT)

This shows two ways in which you can use JWTs for authentication. 
- With `RS256` tokens issues by third party providers. 
- And generating it's own JWTs after a basic username/password authentication 

For the third party authentication to work you need to supply a URL to the JSON Web Key Store (JWKS).

## Usage

### With Third Party Provider

You can test the sample as follows:

Add `JWKS_URL` to your environment variables. If you're using Auth0, you can find
the jwks url in the Application Settings -> Advanced Settings -> "Endpoints", it
should look like this:

```
JWKS_URL=https://<your-account-name>.<region>.auth0.com/.well-known/jwks.json
```

Point your web app to your server with the `Authorization` header, or copy the
access token into `cURL`:

```
curl \
  -H "Authorization: Bearer ey..." \
  localhost:8080/auth
```

It should return a response with status 200 and the body text "Authenticated (Subject: ...)", with the JWT subject 
name included.

### Locally Generated JWTs

Locally generated JWTs require you to create a user and login using basic username/password authentication. 

Users are created with the route PUT /user. This body should be JSON and include a `name` and `password` 
field. Login (POST /user) uses basic authentication and its response will include a JSON body with the JWT token in a 
`token` field. This token can then be used in a similar manner to the third part provider to add authentication
to any route.

The first time you run the app you should include the `--migrate` command line parameter to setup the database.

This example comes with a [PAW](https://paw.cloud/) file you can use to test the various endpoints.
