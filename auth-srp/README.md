# Authentication using SRP

Application demonstrating authentication using Secure Remote Password.

Secure Remote Password (SRP) is a method to authenticate with your server application without ever passing your password to the server. Because the server never knows your password it can never be leaked in an attack on the server. Also because the password is never passed to the server it can not be obtained via an eavesdropper or man in the middle attack.

The authentication works by the client demonstrating to the server they know the password without sending the password. Furthermore the server then has to demonstrate to the client it knows enough about the password, to avoid phishing attacks. More can be found out about SRP [here](https://datatracker.ietf.org/doc/html/rfc2945). Wikipedia also have a detailed description of the method [here](https://en.wikipedia.org/wiki/Secure_Remote_Password_protocol).

Because this example serves a couple of web pages, you will need to make sure you have set the working directory to the root folder of the example before running. Also the example uses Fluent to store data in a database. The first time you run it you should include the command line argument `--migrate`.

Once the application is running use your browser to visit `http://localhost:8080/index.html`. From here you will be able to create a new user. Once the user is created you will be redirected to a login page where you can then test the login process. The client side Javascript SRP code uses the library https://github.com/symeapp/srp-client. This library is licensed under the Mozilla Public License 2.0 license. 

If you look at the JS code at the top of `index.html` you will see during the create user process the username, a random salt and a verifier are passed to the server. The verifier is created from the username, password and salt. The password is not passed to the server.

The login process found in `login.html` has a number of stages. 

1) The client creates a random private key, and derived public key. 
2) The public key is sent to the server along with the username. 
3) The server looks up the salt and verifier associated with the username.
4) The server then generates its own public/private key pair and returns its public key, the salt associated with the username and a session key. It will store the data required to finished the authentication in an SRP session object and this is then stored alongside the session key using the [persist](https://github.com/hummingbird-project/hummingbird/blob/main/Sources/Hummingbird/Storage/Application%2BPersist.swift) framework.
5) The client creates a shared secret from its own public/private key pair, the public server key, the username, password and salt. 
6) The server is also able to create this shared secret using its own public/private key pair, the public client key and the verifier associated with the username.
7) At this point the client could send the secret to the server and they could be compared, but instead the client sends a proof (derived from the data both client and server have) that it knows the shared secret, along with the session key so the server can find SRP session data it stored from the previous call.
8) The server verifies the proof and then replies with its own proof that it knows the shared secret.
9) If the server proof is verified then the client can be considered authenticated.

If at any stage any of these fail, then the process is aborted.
