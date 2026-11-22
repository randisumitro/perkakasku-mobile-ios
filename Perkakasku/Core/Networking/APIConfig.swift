import Foundation

/// Deployment target for the Perkakasku API.
enum APIEnvironment: String, CaseIterable, Identifiable {
    case development
    case production

    var id: String { rawValue }

    var label: String {
        switch self {
        case .development: return "Local Docker (127.0.0.1:4000)"
        case .production: return "Production (perkakasku.cloud)"
        }
    }

    var defaultURLString: String {
        switch self {
        case .development: return "http://127.0.0.1:4000"
        case .production: return "https://perkakasku.cloud"
        }
    }
}

/// Central API configuration. Supports switching between local Docker backend and production.
struct APIConfig {
    private static let customURLKey = "pk_custom_backend_url"
    private static let envKey = "pk_api_environment"

    static var environment: APIEnvironment {
        get {
            if let raw = UserDefaults.standard.string(forKey: envKey),
               let parsed = APIEnvironment(rawValue: raw) {
                return parsed
            }
            return .development
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: envKey)
        }
    }

    static var customURLOverride: String? {
        get {
            let val = UserDefaults.standard.string(forKey: customURLKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (val?.isEmpty == false) ? val : nil
        }
        set {
            let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: customURLKey)
            } else {
                UserDefaults.standard.set(trimmed, forKey: customURLKey)
            }
        }
    }

    static var baseURL: URL {
        if let override = customURLOverride, let url = URL(string: override), url.scheme != nil {
            return url
        }
        return URL(string: environment.defaultURLString)!
    }

    static let requestTimeout: TimeInterval = 120
    static let resourceTimeout: TimeInterval = 300
}
