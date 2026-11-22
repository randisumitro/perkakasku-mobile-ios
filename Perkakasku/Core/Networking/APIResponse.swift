import Foundation

/// Standard envelope returned by the Perkakasku backend:
/// { "success": Bool, "message": String, "data": ... }
struct APIResponse<T: Codable & Sendable>: Codable, Sendable {
    let success: Bool
    let message: String
    let data: T?
}

/// Placeholder for endpoints that return no meaningful payload.
struct EmptyData: Codable, Sendable {}
