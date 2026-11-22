import Foundation
import UIKit

/// Higher-level API operations for server-backed processing tools and public telemetry/catalog endpoints.
/// Every tool response properly decodes the backend `{ success, message, data: { bytesBase64, ... } }` envelope.
@MainActor
final class APIService: ObservableObject {
    static let shared = APIService()

    private let client = APIClient.shared

    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var error: String?

    private init() {}

    // MARK: - Health & Metadata

    func checkHealth() async throws -> (BackendHealthResponse, Int) {
        let start = Date()
        let endpoint = RawEndpoint(path: "/health", method: .GET, requiresAuth: false)
        let data = try await client.send(endpoint, timeout: 6)
        let decoded = try JSONDecoder().decode(BackendHealthResponse.self, from: data)
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        return (decoded, ms)
    }

    func capabilities() async throws -> ServerCapabilitiesData {
        let endpoint = RawEndpoint(path: "/api/tools/capabilities", method: .GET, requiresAuth: false)
        return try await client.sendDecodable(endpoint, as: ServerCapabilitiesData.self)
    }

    func fetchPublicPlans() async throws -> [PublicPlan] {
        let endpoint = RawEndpoint(path: "/api/v1/public/plans", method: .GET, requiresAuth: false)
        let data = try await client.send(endpoint, timeout: 10)
        return try JSONDecoder().decode(PublicPlansEnvelope.self, from: data).plans
    }

    /// Fire-and-forget anonymous usage logging matching web client (`POST /api/v1/public/usage`).
    func recordUsage(toolSlug: String, fileCount: Int = 1, totalBytes: Int64 = 0) async {
        let payload: [String: Any] = [
            "toolSlug": toolSlug,
            "fileCount": max(1, fileCount),
            "totalBytes": max(0, totalBytes),
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        let endpoint = RawEndpoint(path: "/api/v1/public/usage", method: .POST, body: body, requiresAuth: false)
        _ = try? await client.send(endpoint, timeout: 5)
    }

    // MARK: - Server-backed tool endpoints

    /// POST /api/tools/pdf-compress (field "file", field "level": low|balanced|high)
    func compressPDF(file: MultipartFile, level: String = "balanced") async throws -> DecodedServerFile {
        try await runFileTool(
            path: "/api/tools/pdf-compress",
            file: file,
            fields: ["level": level],
            fallbackName: "compressed.pdf",
            fallbackMime: "application/pdf"
        )
    }

    /// POST /api/tools/pdf-to-excel (field "file", optional "pages", "sheetName")
    func pdfToExcel(file: MultipartFile, pages: String? = nil, sheetName: String = "Sheet1") async throws -> DecodedServerFile {
        var fields: [String: String] = ["sheetName": sheetName]
        if let pages, !pages.trimmingCharacters(in: .whitespaces).isEmpty {
            fields["pages"] = pages
        }
        return try await runFileTool(
            path: "/api/tools/pdf-to-excel",
            file: file,
            fields: fields,
            fallbackName: "extracted.xlsx",
            fallbackMime: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )
    }

    /// POST /api/tools/pdf-to-word (field "file")
    func pdfToWord(file: MultipartFile) async throws -> DecodedServerFile {
        try await runFileTool(
            path: "/api/tools/pdf-to-word",
            file: file,
            fields: [:],
            fallbackName: "converted.docx",
            fallbackMime: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        )
    }

    /// POST /api/tools/word-to-pdf (field "file")
    func wordToPDF(file: MultipartFile) async throws -> DecodedServerFile {
        try await runFileTool(
            path: "/api/tools/word-to-pdf",
            file: file,
            fields: [:],
            fallbackName: "converted.pdf",
            fallbackMime: "application/pdf"
        )
    }

    /// POST /api/tools/passport-photo (field "file", "preset", "dpi")
    func passportPhoto(file: MultipartFile, preset: String = "3x4", dpi: Int = 300) async throws -> DecodedServerFile {
        try await runFileTool(
            path: "/api/tools/passport-photo",
            file: file,
            fields: ["preset": preset, "dpi": "\(dpi)"],
            fallbackName: "passport-\(preset)-\(dpi)dpi.jpg",
            fallbackMime: "image/jpeg"
        )
    }

    /// POST /api/tools/heic-to-jpg (field "file", "quality", "stripMetadata")
    func heicToJPG(file: MultipartFile, quality: Double = 0.9, stripMetadata: Bool = true) async throws -> DecodedServerFile {
        try await runFileTool(
            path: "/api/tools/heic-to-jpg",
            file: file,
            fields: [
                "quality": String(format: "%.2f", quality),
                "stripMetadata": stripMetadata ? "true" : "false",
            ],
            fallbackName: "converted.jpg",
            fallbackMime: "image/jpeg"
        )
    }

    /// POST /api/tools/background-remove (requires external provider configured on server)
    func removeBackground(file: MultipartFile, consentExternal: Bool) async throws -> DecodedServerFile {
        try await runFileTool(
            path: "/api/tools/background-remove",
            file: file,
            fields: ["consentExternal": consentExternal ? "true" : "false"],
            fallbackName: "cutout-nobg.png",
            fallbackMime: "image/png"
        )
    }

    // MARK: - Helper

    private func runFileTool(
        path: String,
        file: MultipartFile,
        fields: [String: String],
        fallbackName: String,
        fallbackMime: String
    ) async throws -> DecodedServerFile {
        isProcessing = true
        error = nil
        progress = 0.15
        defer {
            isProcessing = false
            progress = 0
        }

        let endpoint = RawEndpoint(path: path, method: .POST, requiresAuth: false)
        let fileData = try await client.uploadMultipartDecodable(
            endpoint,
            files: [file],
            fields: fields,
            as: ServerToolFileData.self
        )
        progress = 0.85

        guard let base64 = fileData.bytesBase64,
              let decodedBytes = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
              !decodedBytes.isEmpty else {
            throw APIError.noData
        }

        progress = 1.0
        return DecodedServerFile(
            data: decodedBytes,
            fileName: fileData.fileName ?? fallbackName,
            mimeType: fileData.mimeType ?? fallbackMime,
            metadata: fileData
        )
    }
}
