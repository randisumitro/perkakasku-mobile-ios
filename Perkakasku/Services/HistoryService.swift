import Foundation
import SwiftData
import SwiftUI

/// Manages local processing history in SwiftData and tracks recently opened tools.
@MainActor
final class HistoryService: ObservableObject {
    static let shared = HistoryService()

    @Published private(set) var items: [ProcessedItemModel] = []
    @Published private(set) var recentSlugs: [String] = []

    private let recentKey = "pk_recent_tool_slugs"
    private let maxRecentCount = 8

    private init() {
        self.recentSlugs = UserDefaults.standard.stringArray(forKey: recentKey) ?? []
        reload()
    }

    var totalProcessedCount: Int { items.count }

    func reload() {
        let context = SwiftDataStack.shared.container.mainContext
        let descriptor = FetchDescriptor<ProcessedItemModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        items = (try? context.fetch(descriptor)) ?? []
    }

    func markToolOpened(_ slug: String) {
        var updated = recentSlugs.filter { $0 != slug }
        updated.insert(slug, at: 0)
        if updated.count > maxRecentCount {
            updated = Array(updated.prefix(maxRecentCount))
        }
        recentSlugs = updated
        UserDefaults.standard.set(updated, forKey: recentKey)
    }

    func recentTools(from allTools: [Tool]) -> [Tool] {
        var seen = Set<String>()
        var result: [Tool] = []

        // First include slugs from actual processed jobs
        for item in items {
            if !seen.contains(item.toolSlug), let tool = allTools.first(where: { $0.slug == item.toolSlug }) {
                result.append(tool)
                seen.insert(item.toolSlug)
            }
            if result.count >= 6 { return result }
        }

        // Then fill with recently opened tools
        for slug in recentSlugs {
            if !seen.contains(slug), let tool = allTools.first(where: { $0.slug == slug }) {
                result.append(tool)
                seen.insert(slug)
            }
            if result.count >= 6 { break }
        }
        return result
    }

    func record(
        tool: Tool,
        inputFileName: String,
        outputFileName: String? = nil,
        outputURL: URL? = nil,
        status: ProcessingStatus = .completed,
        fileSize: Int64 = 0,
        fileCount: Int = 1
    ) {
        let context = SwiftDataStack.shared.container.mainContext
        let entry = ProcessedItemModel(
            toolSlug: tool.slug,
            toolName: tool.name,
            category: tool.category,
            inputFileName: inputFileName,
            outputFileName: outputFileName ?? outputURL?.lastPathComponent,
            outputURL: outputURL,
            mode: tool.mode,
            status: status,
            createdAt: Date(),
            fileSize: fileSize
        )
        context.insert(entry)
        try? context.save()
        markToolOpened(tool.slug)
        reload()

        if status == .completed {
            let webSlug = tool.webSlug
            Task {
                await APIService.shared.recordUsage(
                    toolSlug: webSlug,
                    fileCount: fileCount,
                    totalBytes: fileSize
                )
            }
        }
    }

    func delete(_ item: ProcessedItemModel) {
        let context = SwiftDataStack.shared.container.mainContext
        if let urlString = item.outputURLString, let url = URL(string: urlString) {
            LocalFileManager.shared.delete(at: url)
        }
        context.delete(item)
        try? context.save()
        reload()
    }

    func clearAll() {
        let context = SwiftDataStack.shared.container.mainContext
        for item in items {
            context.delete(item)
        }
        try? context.save()
        reload()
    }
}
