import Hummingbird
import HummingbirdAuth
import HummingbirdRouter
import ServiceLifecycle
import SotoCognitoAuthenticationKit

struct AWSClientService: Service {
    let client: AWSClient

    func run() async throws {
        await GracefulShutdownWaiter().wait()
        try await self.client.shutdown()
    }
}

func buildApplication(configuration: HBApplicationConfiguration) async throws -> some HBApplicationProtocol {
    // setup Soto
    let awsClient = AWSClient(httpClientProvider: .createNew)
    let cognitoIdentityProvider = CognitoIdentityProvider(client: awsClient, region: .euwest1)
    // setup SotoCognitoAuthentication
    let env = try await HBEnvironment().merging(with: .dotEnv())
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

    let router = HBRouterBuilder(context: AuthCognitoRequestContext.self) {
        AWSErrorMiddleware()
        UserController(cognitoAuthenticatable: authenticatable, cognitoIdentityProvider: cognitoIdentityProvider).endpoints
    }

    var app = HBApplication(router: router)
    app.addServices(AWSClientService(client: awsClient))
    return app
}
