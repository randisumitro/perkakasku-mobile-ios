import Foundation
import SwiftUI

/// Provides the authoritative tool catalog to the UI layer.
@MainActor
final class ToolRegistryService: ObservableObject {
    static let shared = ToolRegistryService()

    @Published var tools: [Tool] = ToolRegistry.all
    @Published var categories: [ToolCategory] = ToolCategory.allCases

    private init() {}

    func tools(in category: ToolCategory) -> [Tool] {
        tools.filter { $0.category == category }
    }

    func tool(slug: String) -> Tool? {
        ToolRegistry.tool(slug: slug)
    }

    var allLocalTools: [Tool] { tools.filter { $0.isLocalOnly } }
    var allServerTools: [Tool] { tools.filter { !$0.isLocalOnly } }
}
