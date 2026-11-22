// xcode: set sdk=iOS

import SwiftUI

/// Clean category hub for Document & Utility tools when navigated directly.
struct DocumentToolView: View {
    @EnvironmentObject private var registry: ToolRegistryService

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: 12)], spacing: 12) {
                ForEach(registry.tools(in: .document)) { tool in
                    NavigationLink(value: tool) {
                        ToolCard(tool: tool)
                    }
                    .buttonStyle(PKPressButtonStyle())
                }
            }
            .padding(16)
        }
        .background(PKStudioBackdrop(showGrid: false))
        .navigationTitle(ToolCategory.document.displayName)
    }
}
