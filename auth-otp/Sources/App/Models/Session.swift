import Foundation

/// States required by Session
enum Session: Codable {
    enum Challenge: Codable {
        case totp(UUID)
    }
    case authenticated(UUID)
    case challenge(Challenge)
}