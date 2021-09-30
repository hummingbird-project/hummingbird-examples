import Hummingbird
import HummingbirdFoundation
import SotoCognitoAuthenticationKit

extension HBApplication {
    /// configure your application
    /// add middleware
    /// setup the encoder/decoder
    /// add your routes
    public func configure() throws {
        let env = HBEnvironment()
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()

        // setup Soto
        self.aws.client = AWSClient(httpClientProvider: .createNewWithEventLoopGroup(self.eventLoopGroup))
        self.aws.cognitoIdentityProvider = CognitoIdentityProvider(client: self.aws.client, region: .euwest1)

        // setup SotoCognitoAuthentication
        guard let userPoolId = env.get("cognito_user_pool_id"),
              let clientId = env.get("cognito_client_id") else {
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
}
