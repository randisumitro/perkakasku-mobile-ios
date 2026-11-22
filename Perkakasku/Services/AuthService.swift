import Foundation
import SwiftData

/// Authentication service: preserves login/register/token management for future activation
/// while defaulting to an open guest session during the current development phase.
@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    private let client = APIClient.shared
    private static let guestIDKey = "pk_guest_session_id"

    @Published var user: User?
    @Published var isAuthenticated: Bool = false
    @Published var isGuestSession: Bool = true
    @Published var isLoading = false
    @Published var error: String?

    var guestIdentifier: String {
        if let existing = UserDefaults.standard.string(forKey: Self.guestIDKey), !existing.isEmpty {
            return existing
        }
        let fresh = "ios-guest-\(UUID().uuidString)"
        UserDefaults.standard.set(fresh, forKey: Self.guestIDKey)
        return fresh
    }

    var effectiveDisplayName: String {
        user?.name ?? "Guest Studio"
    }

    private init() {
        // Guest mode is active immediately at launch; do not auto-trigger /account/me
        // or block entry with authentication screens during this development phase.
        self.isGuestSession = true
        self.isAuthenticated = false
    }

    var token: String? { KeychainHelper.shared.token }

    func login(email: String, password: String) async throws -> AuthResponse {
        isLoading = true; error = nil
        defer { isLoading = false }
        let body = try JSONEncoder().encode(["email": email, "password": password])
        let endpoint = RawEndpoint(path: "/api/v1/auth/login", method: .POST, body: body, requiresAuth: false)
        let data = try await client.send(endpoint)
        let response = try decodeAuthResponse(from: data)
        KeychainHelper.shared.token = response.token
        self.user = response.user
        self.isAuthenticated = true
        self.isGuestSession = false
        return response
    }

    func register(email: String, password: String, name: String? = nil) async throws -> AuthResponse {
        isLoading = true; error = nil
        defer { isLoading = false }
        var payload: [String: Any] = ["email": email, "password": password]
        if let name { payload["name"] = name }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let endpoint = RawEndpoint(path: "/api/v1/auth/register", method: .POST, body: body, requiresAuth: false)
        let data = try await client.send(endpoint)
        if let response = try? decodeAuthResponse(from: data) {
            KeychainHelper.shared.token = response.token
            self.user = response.user
            self.isAuthenticated = true
            self.isGuestSession = false
            return response
        }
        // Backend registration returns { message } and requires email verification before token issuance.
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = obj["message"] as? String {
            throw APIError.serverError(201, message)
        }
        throw APIError.noData
    }

    func logout() {
        KeychainHelper.shared.token = nil
        self.user = nil
        self.isAuthenticated = false
        self.isGuestSession = true
    }

    func loadMe() async {
        guard KeychainHelper.shared.token != nil else {
            self.isAuthenticated = false
            self.isGuestSession = true
            return
        }
        do {
            let endpoint = RawEndpoint(path: "/api/v1/account/me", method: .GET, body: nil, requiresAuth: true)
            let data = try await client.send(endpoint)
            let u = try decodeUser(from: data)
            self.user = u
            self.isAuthenticated = true
            self.isGuestSession = false
        } catch {
            self.isAuthenticated = false
            self.isGuestSession = true
            KeychainHelper.shared.token = nil
        }
    }

    private func decodeAuthResponse(from data: Data) throws -> AuthResponse {
        let decoder = JSONDecoder()
        if let direct = try? decoder.decode(AuthResponse.self, from: data) {
            return direct
        }
        let envelope = try decoder.decode(APIResponse<AuthResponse>.self, from: data)
        guard envelope.success else {
            throw APIError.serverError(0, envelope.message)
        }
        guard let value = envelope.data else { throw APIError.noData }
        return value
    }

    private func decodeUser(from data: Data) throws -> User {
        let decoder = JSONDecoder()
        if let wrapper = try? decoder.decode(UserEnvelope.self, from: data) {
            return wrapper.user
        }
        if let direct = try? decoder.decode(User.self, from: data) {
            return direct
        }
        let envelope = try decoder.decode(APIResponse<User>.self, from: data)
        guard envelope.success else {
            throw APIError.serverError(0, envelope.message)
        }
        guard let value = envelope.data else { throw APIError.noData }
        return value
    }
}

private struct UserEnvelope: Decodable {
    let user: User
}

/// Minimal endpoint carrying a raw JSON body.
struct RawEndpoint: Endpoint {
    let path: String
    let method: HTTPMethod
    let body: Data?
    let requiresAuth: Bool
    init(path: String, method: HTTPMethod, body: Data? = nil, requiresAuth: Bool) {
        self.path = path
        self.method = method
        self.body = body
        self.requiresAuth = requiresAuth
    }
    var additionalHeaders: [String: String] { [:] }
    var queryItems: [URLQueryItem] { [] }
}
