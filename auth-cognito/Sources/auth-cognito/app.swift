import Hummingbird
import HummingbirdFoundation
import SotoCognitoAuthenticationKit

func runApp(_ arguments: HummingbirdArguments) {
    let env = HBEnvironment()
    let app = HBApplication(configuration: .init(address: .hostname(arguments.hostname, port: arguments.port)))
    app.encoder = JSONEncoder()
    app.decoder = JSONDecoder()

    // setup Soto
    app.aws.client = AWSClient(httpClientProvider: .createNewWithEventLoopGroup(app.eventLoopGroup))
    app.aws.cognitoIdentityProvider = CognitoIdentityProvider(client: app.aws.client, region: .euwest1)

    // setup SotoCognitoAuthentication
    guard let userPoolId = env.get("cognito_user_pool_id"),
          let clientId = env.get("cognito_client_id") else {
        preconditionFailure("Requires \"cognito_user_pool_id\" and \"cognito_client_id\" environment variables")
    }
    let config = CognitoConfiguration(
        userPoolId: userPoolId,
        clientId: clientId,
        clientSecret: env.get("cognito_client_secret"),
        cognitoIDP: app.aws.cognitoIdentityProvider
    )
    app.cognito.authenticatable = CognitoAuthenticatable(configuration: config)

    // middleware
    app.middleware.add(ErrorLoggingMiddleware())
    
    let userController = UserController()
    userController.addRoutes(to: app.router.group("user"))

    app.start()
    app.wait()
}
