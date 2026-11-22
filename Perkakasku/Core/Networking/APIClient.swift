import Foundation

/// Errors produced by the API layer.
enum APIError: LocalizedError, Sendable {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case serverError(Int, String)
    case decodingError(Error)
    case unauthorized
    case noData
    case networkUnavailable
    case timeout
    case fileTooLarge(String)

    var errorDescription: String? {
        localizedDescription
    }

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid backend URL configuration."
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server."
        case .serverError(let code, let message):
            return code > 0 ? "Server error (\(code)): \(message)" : message
        case .decodingError(let error):
            return "Could not decode server response: \(error.localizedDescription)"
        case .unauthorized:
            return "Authentication required for this endpoint."
        case .noData:
            return "No output data received from server."
        case .networkUnavailable:
            return "Cannot reach the Perkakasku backend. Ensure Docker is running at \(APIConfig.baseURL.absoluteString)."
        case .timeout:
            return "The server took too long to process this file. Try a smaller file or retry."
        case .fileTooLarge(let message):
            return message
        }
    }
}

/// Thin URLSession client. Holds no mutable state so it is safe to share.
final class APIClient: Sendable {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder = JSONDecoder()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.requestTimeout
        config.timeoutIntervalForResource = APIConfig.resourceTimeout
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }

    // MARK: - Send (raw data)

    /// Send an endpoint and return the raw response data.
    func send(_ endpoint: some Endpoint, timeout: TimeInterval? = nil) async throws -> Data {
        var request = try buildRequest(endpoint)
        if let timeout {
            request.timeoutInterval = timeout
        }
        return try await perform(request)
    }

    // MARK: - Send decodable

    /// Send an endpoint and decode the response envelope into `T`.
    func sendDecodable<E: Endpoint, T: Codable & Sendable>(
        _ endpoint: E,
        as type: T.Type = T.self
    ) async throws -> T {
        let data = try await send(endpoint)
        return try decodeEnvelope(from: data, as: type)
    }

    // MARK: - Multipart upload

    /// Upload form fields + files as multipart/form-data and return raw data.
    func uploadMultipart<E: Endpoint>(
        _ endpoint: E,
        files: [MultipartFile],
        fields: [String: String] = [:]
    ) async throws -> Data {
        let (request, tempFileURL) = try buildMultipartFileRequest(endpoint, files: files, fields: fields)
        defer {
            if let tempFileURL {
                try? FileManager.default.removeItem(at: tempFileURL)
            }
        }
        do {
            let (data, response): (Data, URLResponse)
            if let tempFileURL {
                (data, response) = try await session.upload(for: request, fromFile: tempFileURL)
            } else {
                (data, response) = try await session.data(for: request)
            }
            guard let http = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            try validate(statusCode: http.statusCode, data: data)
            return data
        } catch let error as APIError {
            throw error
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        } catch {
            throw APIError.requestFailed(error)
        }
    }

    /// Upload multipart files and decode the `APIResponse<T>` envelope cleanly.
    func uploadMultipartDecodable<E: Endpoint, T: Codable & Sendable>(
        _ endpoint: E,
        files: [MultipartFile],
        fields: [String: String] = [:],
        as type: T.Type = T.self
    ) async throws -> T {
        let data = try await uploadMultipart(endpoint, files: files, fields: fields)
        return try decodeEnvelope(from: data, as: type)
    }

    /// Perform a raw GET and return (data, HTTPURLResponse), validating status codes.
    func getRaw(url: URL, timeout: TimeInterval = 15) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            try validate(statusCode: http.statusCode, data: data)
            return (data, http)
        } catch let error as APIError {
            throw error
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        } catch {
            throw APIError.requestFailed(error)
        }
    }

    // MARK: - Private Execution & Decoding

    private func perform(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            try validate(statusCode: http.statusCode, data: data)
            return data
        } catch let error as APIError {
            throw error
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        } catch {
            throw APIError.requestFailed(error)
        }
    }

    private func decodeEnvelope<T: Codable & Sendable>(from data: Data, as type: T.Type) throws -> T {
        guard !data.isEmpty else { throw APIError.noData }
        do {
            let envelope = try decoder.decode(APIResponse<T>.self, from: data)
            guard envelope.success else {
                throw APIError.serverError(0, envelope.message)
            }
            guard let value = envelope.data else { throw APIError.noData }
            return value
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func mapURLError(_ error: URLError) -> APIError {
        switch error.code {
        case .timedOut:
            return .timeout
        case .cannotConnectToHost, .cannotFindHost, .notConnectedToInternet, .networkConnectionLost, .dnsLookupFailed:
            return .networkUnavailable
        default:
            return .requestFailed(error)
        }
    }

    // MARK: - Request building

    private func buildRequest(_ endpoint: some Endpoint) throws -> URLRequest {
        guard var components = URLComponents(url: APIConfig.baseURL, resolvingAgainstBaseURL: true) else {
            throw APIError.invalidURL
        }
        components.path = endpoint.path
        if !endpoint.queryItems.isEmpty {
            components.queryItems = endpoint.queryItems
        }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.guestIdentifier, forHTTPHeaderField: "X-Guest-Id")
        if endpoint.requiresAuth, let token = KeychainHelper.shared.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        for (key, value) in endpoint.additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if let body = endpoint.body {
            request.httpBody = body
        }
        return request
    }

    /// Stream multipart body into a temporary file on disk so large uploads do not double memory usage.
    private func buildMultipartFileRequest<E: Endpoint>(
        _ endpoint: E,
        files: [MultipartFile],
        fields: [String: String]
    ) throws -> (URLRequest, URL?) {
        guard var components = URLComponents(url: APIConfig.baseURL, resolvingAgainstBaseURL: true) else {
            throw APIError.invalidURL
        }
        components.path = endpoint.path
        guard let url = components.url else { throw APIError.invalidURL }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Self.guestIdentifier, forHTTPHeaderField: "X-Guest-Id")
        if endpoint.requiresAuth, let token = KeychainHelper.shared.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        for (key, value) in endpoint.additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pk_upload_\(UUID().uuidString).multipart")
        FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: tempURL)
        defer { try? handle.close() }

        for (key, value) in fields {
            try handle.writeUTF8("--\(boundary)\r\n")
            try handle.writeUTF8("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            try handle.writeUTF8("\(value)\r\n")
        }
        for file in files {
            try handle.writeUTF8("--\(boundary)\r\n")
            try handle.writeUTF8("Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.fileName)\"\r\n")
            try handle.writeUTF8("Content-Type: \(file.mimeType)\r\n\r\n")
            try handle.write(contentsOf: file.data)
            try handle.writeUTF8("\r\n")
        }
        try handle.writeUTF8("--\(boundary)--\r\n")
        return (request, tempURL)
    }

    private func validate(statusCode: Int, data: Data) throws {
        switch statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 413:
            let msg = parseErrorMessage(from: data) ?? "Uploaded file exceeds the server size limit."
            throw APIError.fileTooLarge(msg)
        default:
            let msg = parseErrorMessage(from: data) ?? "HTTP \(statusCode)"
            throw APIError.serverError(statusCode, msg)
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        if let errEnv = try? decoder.decode(ServerErrorEnvelope.self, from: data),
           let msg = errEnv.message, !msg.isEmpty {
            return msg
        }
        if let envelope = try? decoder.decode(APIResponse<EmptyData>.self, from: data),
           !envelope.message.isEmpty {
            return envelope.message
        }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errMsg = (obj["message"] as? String) ?? (obj["error"] as? String), !errMsg.isEmpty {
            return errMsg
        }
        let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (raw?.isEmpty == false) ? raw : nil
    }

    private static var guestIdentifier: String {
        let key = "pk_guest_session_id"
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let fresh = "ios-guest-\(UUID().uuidString)"
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }
}

private extension FileHandle {
    func writeUTF8(_ string: String) throws {
        if let data = string.data(using: .utf8) {
            try write(contentsOf: data)
        }
    }
}
