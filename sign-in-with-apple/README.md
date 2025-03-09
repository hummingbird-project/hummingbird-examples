# Sign in with Apple

Example demonstrating adding Sign in with Apple to a website

## Setup

This example requires an Apple developer account.

Before you start you need to setup an app id, service id and private key. 

### App ID

Go to the Apple developer portal and select `Identifiers` under the `Certificates, IDs & Profiles` section. Press the + button, select App IDs, press `Continue`, select `App`, press `Continue`. Add a description and bundle ID and from the list select Sign in with Apple. Press `Continue` and then press `Register`.

### Service ID

Back at the `Identifiers` page press + again, this time select `Services IDs`. Press `Continue`, add a description and identifier. Press `Continue` and then press `Register`. From the list of `Service IDs`, select your service to view its details. Select Sign in with Apple and press `Configure`. Select your associated App ID. You also need to add a public website and redirect URL. For running this example you can use ngrok to create a public version of the server. The redirect URL should be set to `https://<ngrok-address>/siwa-redirect`. Once this is setup press `Continue` and then press `Save`.

### Key

The last thing you need is a private key for client authentication. Back on the `Certificates, Identifiers & Profiles` page, select Keys and press the + button. Add a key name, description and select `Sign in with Apple`. Press the `Configure` button next to the `Sign in with Apple`, select your associated App ID and press `Save`. Press `Continue` and then press `Register`. At this point you can download your key.

## Environment variables

This example needs a number of environment variables setup to run.
- `SIWA_SERVICE_ID`: The identifer you entering when setting up your service ID.
- `SIWA_TEAM_ID`: Your Apple account identifier, a series of 10 letters and numbers.
- `SIWA_JWK_ID`: The Key ID of the private key you setup, a series of 10 letters and numbers.
- `SIWA_KEY`: The contents of the private key you downloaded.
- `SIWA_REDIRECT_URL` The redirect URL you entered when setting up your service ID.