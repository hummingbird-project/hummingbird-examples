# Auth Token (JWT)

This example works with `RS256` tokens issues by 3rd party providers. It
requires a JSON Web Key Store (JWKS) URL.

## Usage

You can test the sample as follows:

Add `JWKS_URL` to your environment (`Product->Scheme->Edit->Run` or
`JWKS_URL=https://... swift run Server`). If you're using Auth0, you can find
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
  localhost:8080
```

It should return a response with status 200 and the body text "Hello".
