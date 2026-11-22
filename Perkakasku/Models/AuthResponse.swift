import Foundation

/// Authenticated user profile returned by `/api/v1/auth/login` and `/api/v1/account/me`.
struct User: Identifiable, Sendable, Codable, Hashable {
    let id: String
    let email: String?
    let name: String?
    let isPremium: Bool
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case mongoId = "_id"
        case email, name, plan, isPremium
        case avatar
        case avatarURL = "avatarUrl"
    }

    init(id: String, email: String?, name: String?, isPremium: Bool, avatarURL: String?) {
        self.id = id
        self.email = email
        self.name = name
        self.isPremium = isPremium
        self.avatarURL = avatarURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let idValue = try container.decodeIfPresent(String.self, forKey: .id) {
            self.id = idValue
        } else if let mongoIdValue = try container.decodeIfPresent(String.self, forKey: .mongoId) {
            self.id = mongoIdValue
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing id or _id")
            )
        }
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        let plan = try container.decodeIfPresent(String.self, forKey: .plan)?.lowercased()
        let explicitPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium)
        self.isPremium = explicitPremium ?? (plan == "premium" || plan == "pro")
        let avatarValue = try container.decodeIfPresent(String.self, forKey: .avatarURL)
            ?? container.decodeIfPresent(String.self, forKey: .avatar)
        self.avatarURL = (avatarValue?.isEmpty == true) ? nil : avatarValue
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(isPremium, forKey: .isPremium)
        try container.encodeIfPresent(avatarURL, forKey: .avatarURL)
    }
}

/// Credentials payload for login / register.
struct AuthCredentials: Sendable, Codable {
    let email: String
    let password: String
}

/// Token + user returned by login / googleLogin.
struct AuthResponse: Sendable, Codable {
    let token: String
    let user: User
}
