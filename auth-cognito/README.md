# Authentication with SotoCognitoAuthenticationKit

Example of app using SotoCognitoAuthenticationKit. App includes four authenticators (basic username and password, basic username and password using SRP (Secure Remote Password) for authentication, JWT Access Token and JWT Id Token.

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

