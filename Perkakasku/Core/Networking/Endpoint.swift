import Foundation

enum HTTPMethod: String, Sendable {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

/// A describable HTTP endpoint. Kept free of associated types so the client
/// can stay a simple, Sendable class.
protocol Endpoint: Sendable {
    /// Path relative to APIConfig.baseURL (e.g. "/api/tools/capabilities").
    var path: String { get }
    var method: HTTPMethod { get }
    /// Query items appended to the URL.
    var queryItems: [URLQueryItem] { get }
    /// Extra headers merged on top of the default ones.
    var additionalHeaders: [String: String] { get }
    /// HTTP body (JSON-encoded or raw).
    var body: Data? { get }
    /// Whether the request must carry a Bearer token.
    var requiresAuth: Bool { get }
}

extension Endpoint {
    var queryItems: [URLQueryItem] { [] }
    var additionalHeaders: [String: String] { [:] }
    var body: Data? { nil }
    var requiresAuth: Bool { false }
}

/// A file part for multipart uploads.
struct MultipartFile: Sendable {
    let fieldName: String
    let fileName: String
    let mimeType: String
    let data: Data
}
