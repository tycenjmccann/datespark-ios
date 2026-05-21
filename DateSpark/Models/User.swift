import Foundation

/// Represents the authenticated user's profile data.
struct User: Codable, Sendable, Equatable {
    let id: String
    let email: String
    let displayName: String
    let avatarURL: URL?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
    }
}
