import Foundation
import SwiftData

/// SwiftData model container for local persistence (history, favorites).
/// Kept actor-isolated so all access happens on the MainActor.
@MainActor
final class SwiftDataStack {
    static let shared = SwiftDataStack()
    let container: ModelContainer

    private init() {
        do {
            let config = ModelConfiguration(for: ProcessedItemModel.self)
            container = try ModelContainer(for: ProcessedItemModel.self, configurations: config)
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }

    var context: ModelContext {
        ModelContext(container)
    }
}

/// SwiftData representation of a processed item (stored locally for history).
@Model
final class ProcessedItemModel {
    var id: UUID
    var toolSlug: String
    var toolName: String
    var categoryRaw: String
    var inputFileName: String
    var outputFileName: String?
    var outputURLString: String?
    var modeRaw: String
    var statusRaw: String
    var createdAt: Date
    var fileSize: Int64

    init(id: UUID = UUID(), toolSlug: String, toolName: String,
         category: ToolCategory, inputFileName: String,
         outputFileName: String? = nil, outputURL: URL? = nil,
         mode: ProcessingMode, status: ProcessingStatus = .completed,
         createdAt: Date = Date(), fileSize: Int64 = 0) {
        self.id = id
        self.toolSlug = toolSlug
        self.toolName = toolName
        self.categoryRaw = category.rawValue
        self.inputFileName = inputFileName
        self.outputFileName = outputFileName
        self.outputURLString = outputURL?.absoluteString
        self.modeRaw = mode.rawValue
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.fileSize = fileSize
    }

    var domainModel: ProcessedItem {
        ProcessedItem(
            toolSlug: toolSlug, toolName: toolName,
            category: ToolCategory(rawValue: categoryRaw) ?? .document,
            inputFileName: inputFileName, outputFileName: outputFileName,
            outputURL: outputURLString.flatMap { URL(string: $0) },
            mode: ProcessingMode(rawValue: modeRaw) ?? .server,
            status: ProcessingStatus(rawValue: statusRaw) ?? .completed,
            createdAt: createdAt, fileSize: fileSize
        )
    }
}
