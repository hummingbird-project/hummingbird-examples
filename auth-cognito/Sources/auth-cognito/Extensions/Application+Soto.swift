import Hummingbird
import SotoCognitoAuthenticationKit

extension HBApplication {
    struct AWS {
        var client: AWSClient {
            get { self.application.extensions.get(\.aws.client) }
            nonmutating set {
                self.application.extensions.set(\.aws.client, value: newValue) { client in
                    try client.syncShutdown()
                }
            }
        }
        var cognitoIdentityProvider: CognitoIdentityProvider {
            get { self.application.extensions.get(\.aws.cognitoIdentityProvider) }
            nonmutating set { self.application.extensions.set(\.aws.cognitoIdentityProvider, value: newValue) }
        }

        let application: HBApplication
    }

    var aws: AWS { .init(application: self) }

    struct Cognito {
        var authenticatable: CognitoAuthenticatable {
            get { self.application.extensions.get(\.cognito.authenticatable) }
            nonmutating set { self.application.extensions.set(\.cognito.authenticatable, value: newValue) }
        }

        let application: HBApplication
    }

    var cognito: Cognito { .init(application: self)}
}

