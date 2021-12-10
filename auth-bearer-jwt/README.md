# Auth Bearer Token (JWT)

You can test the sample as follows:

```
curl \
  -H "Accept: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c" \
  localhost:8080/
```

It should return a response with status 200 and the body text "John Doe".

Token data (from [jwt.io](https://jwt.io):

```json
{
  "sub": "1234567890",
  "name": "John Doe",
  "iat": 1516239022
}
```
