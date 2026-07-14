# Encrypted Auth Token (nested JWE)

This example shows how to issue confidential auth tokens using [JWSETKit](https://github.com/amosavian/JWSETKit): a signed JWT nested inside a JWE (RFC 7516, RFC 7519 §11.2), the construct OpenID Connect uses for encrypted ID tokens.

A plain JWT is only base64url encoded, so whoever holds it can read every claim. Here the server signs the claims (ES256) and then encrypts the signed JWT into a JWE (`cty: "JWT"`, ECDH-ES+A256KW, A256GCM), so private claims such as `email` and `role` stay readable by the server alone. The authenticator decrypts the bearer token, verifies the inner JWT (signature, expiry and audience) and only then accepts the identity.

## Usage

- Users are created with the route PUT /user. The body for this request should be JSON and include `name` and `password` fields, plus `email` and `role`, the private claims carried inside the token.
- Login (POST /user/login) uses basic authentication and its response will include a JSON body with the token in a `token` field.
- GET /auth requires that token as a bearer token and returns the private claims decrypted from it.

```sh
curl -X PUT localhost:8080/user -H 'Content-Type: application/json' \
  -d '{"name":"alice","password":"alice-password","email":"alice@example.com","role":"admin"}'

TOKEN=$(curl -s -X POST -u alice:alice-password localhost:8080/user/login | sed 's/.*"token":"\([^"]*\)".*/\1/')

curl -H "Authorization: Bearer $TOKEN" localhost:8080/auth
```

Tokens that are expired, signed by an unknown key, encrypted to a different key, or plain (unencrypted) JWS are rejected with `401`.

By default the app uses an in-memory database, so users are cleared on restart. Run with `--db-in-memory=false` (and `--db-migrate` on first run) command line options to persist to `db.sqlite`. The signing and encryption keys are fixed demo keys, so tokens stay valid across restarts.
