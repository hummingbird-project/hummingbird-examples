import Hummingbird
import HummingbirdAuth
import HummingbirdRouter
import ServiceLifecycle
import SotoCognitoAuthenticationKit
import AsyncHTTPClient

struct AWSClientService: Service {
    let client: AWSClient

    func run() async throws {
        // Ignore cancellation error
        try? await gracefulShutdown()
        try await self.client.shutdown()
    }
}

func buildApplication(
    configuration: ApplicationConfiguration
) async throws -> some ApplicationProtocol {
    // setup Soto
    let awsClient = AWSClient(httpClient: HTTPClient.shared)
    let cognitoIdentityProvider = CognitoIdentityProvider(client: awsClient, region: .euwest1)
    // setup SotoCognitoAuthentication
    let env = try await Environment().merging(with: .dotEnv())
    guard let userPoolId = env.get("cognito_user_pool_id"),
          let clientId = env.get("cognito_client_id")
    else {
        preconditionFailure("Requires \"cognito_user_pool_id\" and \"cognito_client_id\" environment variables")
    }
    let config = CognitoConfiguration(
        userPoolId: userPoolId,
        clientId: clientId,
        clientSecret: env.get("cognito_client_secret"),
        cognitoIDP: cognitoIdentityProvider,
        adminClient: true
    )
    let authenticatable = CognitoAuthenticatable(configuration: config)

    let router = RouterBuilder(context: AuthCognitoRequestContext.self) {
        AWSErrorMiddleware()
        UserController(
            cognitoAuthenticatable: authenticatable,
            cognitoIdentityProvider: cognitoIdentityProvider
        ).endpoints
    }

    var app = Application(router: router)
    app.addServices(AWSClientService(client: awsClient))
    return app
}
