import Foundation

// MARK: - Server Tool Response Models

struct ServerErrorDetail: Codable, Sendable {
    let code: String?
}

struct ServerErrorEnvelope: Codable, Sendable {
    let success: Bool?
    let message: String?
    let error: ServerErrorDetail?
}

struct ServerToolFileData: Codable, Sendable {
    let fileName: String?
    let mimeType: String?
    let bytesBase64: String?
    let originalBytes: Int64?
    let outputBytes: Int64?
    let pageCount: Int?
    let convertedPages: Int?
    let extractedPages: Int?
    let extractedChars: Int?
    let totalExtractedChars: Int?
    let tableCount: Int?
    let isScannedPdf: Bool?
    let alreadyOptimal: Bool?
    let previewText: String?
    let engine: String?
    let level: String?
    let format: String?
    let dpi: Int?
    let preset: String?
}

struct ServerCapabilitiesData: Codable, Sendable {
    let backgroundRemoveExternalConfigured: Bool?
}

struct BackendHealthResponse: Codable, Sendable {
    let status: String
    let owner: String?
    let db: String?
    let time: String?
}

struct PublicPlan: Identifiable, Codable, Sendable, Hashable {
    var id: String { code }
    let code: String
    let name: String
    let price: Int
    let durationDays: Int?
    let features: [String]
    let isActive: Bool?

    var formattedPrice: String {
        if price <= 0 { return "Free" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        let formatted = formatter.string(from: NSNumber(value: price)) ?? "\(price)"
        return "Rp \(formatted)"
    }

    var intervalLabel: String {
        guard let durationDays, durationDays > 0 else { return "forever" }
        return "/ \(durationDays) days"
    }
}

struct PublicPlansEnvelope: Codable, Sendable {
    let plans: [PublicPlan]
}

struct DecodedServerFile: Sendable {
    let data: Data
    let fileName: String
    let mimeType: String
    let metadata: ServerToolFileData
}
