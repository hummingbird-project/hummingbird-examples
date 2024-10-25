import Foundation
import HummingbirdAuth
import HummingbirdBasicAuth

struct User: PasswordAuthenticatable {
    struct Flags: OptionSet {
        let rawValue: Int

        init(rawValue: Int) {
            self.rawValue = rawValue
        }

        static var requiresOTP: Flags { .init(rawValue: 1 << 0) }
    }

    let id: UUID
    let name: String
    let email: String
    let passwordHash: String?
    let otpSecret: String?
}
