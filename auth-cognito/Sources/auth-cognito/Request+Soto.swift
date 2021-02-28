import Hummingbird
import SotoCognitoAuthenticationKit

extension HBRequest {
    var aws: HBApplication.AWS { return self.application.aws }
    var cognito: HBApplication.Cognito { return self.application.cognito }
}
