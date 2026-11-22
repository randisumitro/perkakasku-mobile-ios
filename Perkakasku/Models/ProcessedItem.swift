import Foundation

/// A locally recorded processing job / history entry.
struct ProcessedItem: Identifiable, Sendable, Codable, Hashable {
    let id: UUID
    let toolSlug: String
    let toolName: String
    let category: ToolCategory
    let inputFileName: String
    let outputFileName: String?
    let outputURL: URL?
    let mode: ProcessingMode
    let status: ProcessingStatus
    let createdAt: Date
    let fileSize: Int64

    init(toolSlug: String, toolName: String, category: ToolCategory,
         inputFileName: String, outputFileName: String? = nil,
         outputURL: URL? = nil, mode: ProcessingMode,
         status: ProcessingStatus = .completed,
         createdAt: Date = Date(), fileSize: Int64 = 0) {
        self.id = UUID()
        self.toolSlug = toolSlug
        self.toolName = toolName
        self.category = category
        self.inputFileName = inputFileName
        self.outputFileName = outputFileName
        self.outputURL = outputURL
        self.mode = mode
        self.status = status
        self.createdAt = createdAt
        self.fileSize = fileSize
    }
}

enum ProcessingStatus: String, Codable, Sendable, CaseIterable {
    case pending, completed, failed
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}
