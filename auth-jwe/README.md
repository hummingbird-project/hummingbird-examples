# Encrypted Auth Tokens (nested JWE)

Demonstrates *confidential* auth tokens using [JWSETKit](https://github.com/amosavian/JWSETKit): a signed JWT nested inside a JWE (RFC 7516, RFC 7519 §11.2) — the pattern OpenID Connect uses for encrypted ID tokens.

A plain signed JWT (JWS) is only *base64url-encoded*: anyone holding the token can read every claim:

```sh
echo 'eyJzdWIiOiJhbGljZSIsInJvbGUiOiJhZG1pbiJ9' | base64 -d
# {"sub":"alice","role":"admin"}
```

Here the server instead:

1. signs the claims (ES256) — proving it issued them, then
2. encrypts the signed JWT into a JWE (`cty: "JWT"`, ECDH-ES+A256KW, A256GCM) — so private claims (`email`, `role`) are hidden from the client and everyone else.

The middleware decrypts the bearer token, verifies the inner JWT (signature, expiry, audience), and only then accepts the identity.

## Usage

Start the server, then:

```sh
# login (basic auth) to get an encrypted token
TOKEN=$(curl -s -X POST -u alice:alice-password localhost:8080/user/login | sed 's/.*"token":"\([^"]*\)".*/\1/')

# the token has 5 segments (JWE) and decodes to ciphertext, not claims
echo $TOKEN | cut -d. -f3 | base64 -d 2>/dev/null | head -c 40

# the server decrypts it and returns the private claims
curl -H "Authorization: Bearer $TOKEN" localhost:8080/auth
```

The last call returns `{"username":"alice","email":"alice@example.com","role":"admin"}`. Tokens that are expired, signed by an unknown key, encrypted to a different key, or plain (unencrypted) JWS are rejected with `401`.
