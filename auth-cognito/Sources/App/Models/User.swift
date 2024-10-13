import Hummingbird
import HummingbirdAuth
import SotoCognitoAuthenticationKit

struct User: ResponseCodable {
    let username: String
    let email: String

    private enum CodingKeys: String, CodingKey {
        case username = "cognito:username"
        case email
    }
}
