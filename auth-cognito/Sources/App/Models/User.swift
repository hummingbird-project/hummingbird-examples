import Hummingbird
import HummingbirdAuth
import SotoCognitoAuthenticationKit

struct User: HBResponseCodable & HBAuthenticatable {
    let username: String
    let email: String

    private enum CodingKeys: String, CodingKey {
        case username = "cognito:username"
        case email = "email"
    }
}

struct SignUp : Decodable {
    var username : String
    var email : String
}

struct NewPassword: Decodable {
    let username: String
    let password: String
    let session: String
}

struct AccessResponse: HBResponseEncodable {
    let username: String
    let subject: String

    private enum CodingKeys: String, CodingKey {
        case username = "username"
        case subject = "sub"
    }
}

struct SignUpResponse: HBResponseEncodable {
    let username: String
}

struct MfaGetTokenResponse: HBResponseEncodable {
    let secretCode: String
    let session: String?
}
