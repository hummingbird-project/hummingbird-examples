# Authentication with SotoCognitoAuthenticationKit

Example of app using SotoCognitoAuthenticationKit. App includes four authenticators (basic username and password, basic username and password using SRP (Secure Remote Password) for authentication, JWT Access Token and JWT Id Token. This example also uses the result builder router from HummingbirdRouter.

Routes are as follows

- PUT /user - Create a new user
- POST /user/login - Login in user with username and password
- POST /user/login/srp - Login in user with username and password using SRP
- POST /user/respond - Generic response route for any authentication challenges
- POST /user/respond/password - Respond to authenticate challenge with new password
- POST /user/respond/mfa - Respond to authenticate challenge with software MFA code
- GET /user/access - Get contents of access token
- GET /user/id - Get contents of id token
- PATCH /user/attributes - Edit user attributes
- GET /user/mfa/setup - Get user secret code for software MFA
- PUT /user/mfa/setup - Verify user code for software MFA
- POST /user/mfa/enable - Enable software MFA for user
- POST /user/mfa/disable - Disable software MFA for user

This example requires that you setup an AWS Cognito userpool and application client with ADMIN_USER_PASSWORD, REFRESH_TOKEN and USER_SRP authentication methods all enabled. You should then set environment variables `COGNITO_USER_POOL_ID` to the userpool id, `COGNITO_CLIENT_ID` to the application client id and if you added a client secret `COGNITO_CLIENT_SECRET` to that.