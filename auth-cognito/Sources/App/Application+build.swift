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

func buildApplication(configuration: HBApplicationConfiguration) throws -> some HBApplicationProtocol {
    // setup Soto
    let awsClient = AWSClient(httpClientProvider: .createNew)
    let cognitoIdentityProvider = CognitoIdentityProvider(client: awsClient, region: .euwest1)
    // setup SotoCognitoAuthentication
    let env = try HBEnvironment().merging(with: .dotEnv())
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

/* extension HBApplication {
     /// configure your application
     /// add middleware
     /// setup the encoder/decoder
     /// add your routes
     public func configure() throws {
         let env = HBEnvironment()

         // setup Soto
         self.aws.client = AWSClient(httpClientProvider: .createNewWithEventLoopGroup(self.eventLoopGroup))
         self.aws.cognitoIdentityProvider = CognitoIdentityProvider(client: self.aws.client, region: .euwest1)

         // setup SotoCognitoAuthentication
         guard let userPoolId = env.get("cognito_user_pool_id"),
               let clientId = env.get("cognito_client_id")
         else {
             preconditionFailure("Requires \"cognito_user_pool_id\" and \"cognito_client_id\" environment variables")
         }
         let config = CognitoConfiguration(
             userPoolId: userPoolId,
             clientId: clientId,
             clientSecret: env.get("cognito_client_secret"),
             cognitoIDP: self.aws.cognitoIdentityProvider,
             adminClient: true
         )
         self.cognito.authenticatable = CognitoAuthenticatable(configuration: config)

         let userController = UserController()
         userController.addRoutes(to: self.router.group("user"))
     }
 } */
